package academia.dao;

import academia.db.Db;
import academia.util.Seguranca;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class AlunoDAO {

    public List<Map<String, Object>> listar(String busca) throws SQLException {
        String sql = "SELECT id_aluno, id_usuario, nome, cpf, telefone, email, data_nascimento, criado_em "
                   + "FROM aluno ";
        if (busca != null && !busca.isBlank()) {
            return Db.listar(sql + "WHERE nome LIKE ? ORDER BY nome", busca.trim() + "%");
        }
        return Db.listar(sql + "ORDER BY nome");
    }

    public Map<String, Object> cadastrar(String nome, String cpf, String telefone, String email,
                                         LocalDate nascimento, String senha, String idUsuarioLogado)
            throws SQLException {
        try (Connection c = Db.conectar()) {
            c.setAutoCommit(false);
            try {
                Db.definirUsuarioApp(c, idUsuarioLogado);

                String login = cpf == null ? "" : cpf.replaceAll("\\D", "");
                String idUsuario = (String) Db.valor(c, "SELECT fn_gerar_id_usuario()");

                Db.executar(c,
                    "INSERT INTO usuarios (id_usuario, nome, login, email, senha_hash, id_grupo) "
                    + "VALUES (?, ?, ?, ?, ?, 'ALU')",
                    idUsuario, nome, login, vazioParaNulo(email), Seguranca.hash(senha));

                Db.executar(c,
                    "INSERT INTO aluno (id_usuario, nome, cpf, telefone, email, data_nascimento) "
                    + "VALUES (?, ?, ?, ?, ?, ?)",
                    idUsuario, nome, cpf, vazioParaNulo(telefone), vazioParaNulo(email), nascimento);

                String idAluno = (String) Db.valor(c, "SELECT id_aluno FROM aluno WHERE id_usuario = ?", idUsuario);

                c.commit();
                System.out.println("[TCL] COMMIT  - aluno " + idAluno + " / usuário " + idUsuario);

                Map<String, Object> r = new LinkedHashMap<>();
                r.put("id_aluno", idAluno);
                r.put("id_usuario", idUsuario);
                r.put("login", login);
                r.put("transacao", "COMMIT");
                return r;
            } catch (SQLException | RuntimeException e) {
                c.rollback();
                System.out.println("[TCL] ROLLBACK - cadastro de aluno desfeito: " + e.getMessage());
                throw e;
            } finally {
                c.setAutoCommit(true);
            }
        }
    }

    public void atualizar(String idAluno, String nome, String telefone, String email, String idUsuarioLogado)
            throws SQLException {
        try (Connection c = Db.conectar()) {
            Db.definirUsuarioApp(c, idUsuarioLogado);
            int n = Db.executar(c, "UPDATE aluno SET nome = ?, telefone = ?, email = ? WHERE id_aluno = ?",
                    nome, vazioParaNulo(telefone), vazioParaNulo(email), idAluno);
            if (n == 0) throw new IllegalArgumentException("Aluno não encontrado.");
        }
    }

    private static String vazioParaNulo(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
