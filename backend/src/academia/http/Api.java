package academia.http;

import academia.dao.AlunoDAO;
import academia.dao.CatalogoDAO;
import academia.dao.MatriculaDAO;
import academia.dao.UsuarioDAO;
import academia.http.Sessoes.Sessao;
import academia.util.Seguranca;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import java.io.IOException;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class Api implements HttpHandler {

    private final UsuarioDAO usuarios = new UsuarioDAO();
    private final AlunoDAO alunos = new AlunoDAO();
    private final MatriculaDAO matriculas = new MatriculaDAO();
    private final CatalogoDAO catalogo = new CatalogoDAO();

    private static final Set<String> PUBLICO = Set.of();
    private static final Set<String> TODOS = Set.of("ADM", "REC", "ALU");
    private static final Set<String> EQUIPE = Set.of("ADM", "REC");
    private static final Set<String> ADMIN = Set.of("ADM");

    private final List<Rota> rotas = new ArrayList<>();

    public Api() {
        rota("POST", "/api/login", PUBLICO, this::login);
        rota("POST", "/api/logout", TODOS, r -> { Sessoes.encerrar(r.token); return Map.of("ok", true); });
        rota("GET", "/api/sessao", TODOS, this::sessao);

        rota("GET", "/api/painel", EQUIPE, r -> mapa(
                "resumo", catalogo.resumoModalidades(),
                "receita", catalogo.receitaMensal(),
                "inadimplentes", catalogo.inadimplentes()));

        rota("GET", "/api/modalidades", TODOS, r -> catalogo.modalidades());
        rota("GET", "/api/planos", TODOS, r -> catalogo.planos());
        rota("GET", "/api/professores", TODOS, r -> catalogo.professores());
        rota("GET", "/api/simular", TODOS, r -> mapa("valor_total",
                catalogo.simularValor(inteiro(r.query.get("modalidade")), inteiro(r.query.get("plano")))));

        rota("GET", "/api/alunos", EQUIPE, r -> alunos.listar(r.query.get("busca")));
        rota("POST", "/api/alunos", EQUIPE, this::cadastrarAluno);
        rota("PUT", "/api/alunos/([A-Z0-9]+)", EQUIPE, r -> {
            alunos.atualizar(r.p(1), obrig(r, "nome"), r.s("telefone"), r.s("email"), r.sessao.idUsuario());
            return Map.of("ok", true);
        });

        rota("GET", "/api/matriculas", EQUIPE, r -> matriculas.relatorio(
                data(r.query.get("inicio")), data(r.query.get("fim")), vazio(r.query.get("situacao"))));
        rota("POST", "/api/matriculas", TODOS, this::contratar);
        rota("POST", "/api/matriculas/([A-Z0-9-]+)/pagamentos", EQUIPE, r -> {
            exigirIdValido(r.p(1));
            return matriculas.registrarPagamento(r.p(1), obrig(r, "forma"), r.sessao.idUsuario());
        });
        rota("POST", "/api/matriculas/([A-Z0-9-]+)/cancelar", TODOS, this::cancelar);
        rota("GET", "/api/minhas-matriculas", Set.of("ALU"), r -> matriculas.doAluno(r.sessao.idAluno()));

        rota("GET", "/api/usuarios", ADMIN, r -> usuarios.listar());
        rota("POST", "/api/usuarios/([A-Z0-9]+)/ativo", ADMIN, r -> {
            if (r.p(1).equals(r.sessao.idUsuario()))
                throw new IllegalArgumentException("Você não pode desativar o próprio usuário.");
            usuarios.alterarAtivo(r.p(1), Boolean.TRUE.equals(r.body.get("ativo")), r.sessao.idUsuario());
            return Map.of("ok", true);
        });
        rota("GET", "/api/auditoria", ADMIN, r -> usuarios.auditoria());
    }

    private Object login(Req r) throws SQLException {
        String login = obrig(r, "login");
        String senha = obrig(r, "senha");
        Map<String, Object> u = usuarios.autenticar(login, Seguranca.hash(senha));
        if (u == null) throw new ErroHttp(401, "Usuário ou senha inválidos.");
        String token = Sessoes.criar(u);
        return mapa("token", token, "usuario", u);
    }

    private Object sessao(Req r) throws SQLException {
        Sessao s = r.sessao;
        return mapa("usuario", mapa(
                        "id_usuario", s.idUsuario(), "nome", s.nome(), "login", s.login(),
                        "id_grupo", s.idGrupo(), "grupo", s.grupo(),
                        "nivel_acesso", s.nivelAcesso(), "id_aluno", s.idAluno()),
                "conexao", usuarios.infoConexao());
    }

    private Object cadastrarAluno(Req r) throws SQLException {
        return alunos.cadastrar(obrig(r, "nome"), obrig(r, "cpf"), r.s("telefone"), r.s("email"),
                data(r.s("data_nascimento")), obrig(r, "senha"), r.sessao.idUsuario());
    }

    private Object contratar(Req r) throws SQLException {

        String idAluno = "ALU".equals(r.sessao.idGrupo()) ? r.sessao.idAluno() : obrig(r, "id_aluno");
        return matriculas.contratar(idAluno, inteiro(r.body.get("id_modalidade")), inteiro(r.body.get("id_plano")),
                obrig(r, "id_professor"), obrig(r, "forma"), r.sessao.idUsuario());
    }

    private Object cancelar(Req r) throws SQLException {
        String id = r.p(1);
        exigirIdValido(id);
        if ("ALU".equals(r.sessao.idGrupo()) && !matriculas.pertenceAoAluno(id, r.sessao.idAluno()))
            throw new ErroHttp(403, "Esta matrícula não pertence a você.");
        matriculas.cancelar(id, r.s("motivo"), r.sessao.idUsuario());
        return Map.of("ok", true);
    }

    private void exigirIdValido(String id) throws SQLException {
        if (!catalogo.idValido(id))
            throw new IllegalArgumentException("Código de matrícula inválido (dígito verificador não confere).");
    }

    @Override
    public void handle(HttpExchange ex) throws IOException {
        String metodo = ex.getRequestMethod();
        String caminho = ex.getRequestURI().getPath();
        int status = 200;
        Object resposta;
        try {
            Rota rota = null;
            Matcher m = null;
            for (Rota candidata : rotas) {
                Matcher mm = candidata.padrao.matcher(caminho);
                if (candidata.metodo.equals(metodo) && mm.matches()) { rota = candidata; m = mm; break; }
            }
            if (rota == null) throw new ErroHttp(404, "Rota não encontrada.");

            Req req = new Req();
            req.matcher = m;
            req.query = parametros(ex.getRequestURI().getRawQuery());
            String corpo = new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
            Object json = Json.ler(corpo);
            req.body = json instanceof Map<?, ?> mp ? castMap(mp) : new HashMap<>();

            String auth = ex.getRequestHeaders().getFirst("Authorization");
            req.token = auth != null && auth.startsWith("Bearer ") ? auth.substring(7) : null;
            req.sessao = Sessoes.buscar(req.token);

            if (!rota.grupos.isEmpty()) {
                if (req.sessao == null) throw new ErroHttp(401, "Faça login para continuar.");
                if (!rota.grupos.contains(req.sessao.idGrupo()))
                    throw new ErroHttp(403, "Seu grupo (" + req.sessao.grupo() + ") não tem permissão para esta ação.");
            }
            resposta = rota.acao.executar(req);
        } catch (ErroHttp e) {
            status = e.status;
            resposta = Map.of("erro", e.getMessage());
        } catch (IllegalArgumentException e) {
            status = 400;
            resposta = Map.of("erro", e.getMessage());
        } catch (SQLException e) {
            status = statusDoErroSql(e);
            resposta = Map.of("erro", mensagemDoErroSql(e), "sqlstate", String.valueOf(e.getSQLState()));
            System.out.println("[SQL] " + e.getSQLState() + " " + e.getErrorCode() + " - " + e.getMessage());
        } catch (Exception e) {
            status = 500;
            resposta = Map.of("erro", "Erro interno: " + e.getMessage());
            e.printStackTrace();
        }
        System.out.println(metodo + " " + caminho + " -> " + status);
        byte[] bytes = Json.escrever(resposta).getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        ex.sendResponseHeaders(status, bytes.length);
        try (OutputStream os = ex.getResponseBody()) { os.write(bytes); }
    }

    private static int statusDoErroSql(SQLException e) {
        String st = e.getSQLState() == null ? "" : e.getSQLState();
        if (st.startsWith("08")) return 503;
        if (st.equals("45000") || st.startsWith("22") || e.getErrorCode() == 3819) return 400;
        if (st.startsWith("23")) return 409;
        if (st.startsWith("42") && (e.getErrorCode() == 1142 || e.getErrorCode() == 1143 || e.getErrorCode() == 1370))
            return 403;
        return 500;
    }

    private static String mensagemDoErroSql(SQLException e) {
        if (e.getSQLState() != null && e.getSQLState().startsWith("08"))
            return "Não foi possível conectar ao banco de dados. Verifique se o MySQL está rodando.";
        if (e.getErrorCode() == 1045)
            return "Acesso ao banco negado para o usuário da aplicação (confira o db.properties).";
        if (e.getErrorCode() == 1062) {
            String msg = e.getMessage();
            if (msg.contains("cpf") || msg.contains("login")) return "Já existe um cadastro com este CPF/login.";
            if (msg.contains("email")) return "Já existe um usuário com este e-mail.";
            return "Registro duplicado.";
        }
        if (e.getErrorCode() == 1452) return "Referência inválida (aluno, plano, modalidade ou professor inexistente).";
        if (e.getErrorCode() == 3819) return "Dados inválidos: " + e.getMessage();
        return e.getMessage();
    }

    private void rota(String metodo, String regex, Set<String> grupos, Acao acao) {
        rotas.add(new Rota(metodo, Pattern.compile(regex), grupos, acao));
    }

    private record Rota(String metodo, Pattern padrao, Set<String> grupos, Acao acao) {}

    @FunctionalInterface
    private interface Acao { Object executar(Req r) throws Exception; }

    private static final class Req {
        Matcher matcher;
        Map<String, String> query;
        Map<String, Object> body;
        String token;
        Sessao sessao;

        String p(int i) { return matcher.group(i); }

        String s(String chave) {
            Object v = body.get(chave);
            return v == null ? null : (v instanceof BigDecimal b ? b.toPlainString() : v.toString());
        }
    }

    static final class ErroHttp extends RuntimeException {
        private static final long serialVersionUID = 1L;
        final int status;
        ErroHttp(int status, String msg) { super(msg); this.status = status; }
    }

    private static String obrig(Req r, String campo) {
        String v = r.s(campo);
        if (v == null || v.isBlank()) throw new IllegalArgumentException("Campo obrigatório: " + campo);
        return v.trim();
    }

    private static int inteiro(Object v) {
        if (v == null || v.toString().isBlank()) throw new IllegalArgumentException("Informe todos os campos.");
        try {
            return new BigDecimal(v.toString()).intValueExact();
        } catch (NumberFormatException | ArithmeticException e) {
            throw new IllegalArgumentException("Número inválido: " + v);
        }
    }

    private static LocalDate data(String v) {
        if (v == null || v.isBlank()) return null;
        try {
            return LocalDate.parse(v);
        } catch (Exception e) {
            throw new IllegalArgumentException("Data inválida: " + v);
        }
    }

    private static String vazio(String v) { return v == null || v.isBlank() ? null : v; }

    private static Map<String, Object> mapa(Object... kv) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) m.put((String) kv[i], kv[i + 1]);
        return m;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> castMap(Map<?, ?> m) { return (Map<String, Object>) m; }

    private static Map<String, String> parametros(String raw) {
        Map<String, String> m = new HashMap<>();
        if (raw == null) return m;
        for (String par : raw.split("&")) {
            int i = par.indexOf('=');
            if (i <= 0) continue;
            m.put(URLDecoder.decode(par.substring(0, i), StandardCharsets.UTF_8),
                  URLDecoder.decode(par.substring(i + 1), StandardCharsets.UTF_8));
        }
        return m;
    }
}
