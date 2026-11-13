package academia.http;

import java.security.SecureRandom;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public final class Sessoes {
    private static final long DURACAO_MS = 8L * 60 * 60 * 1000;
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Map<String, Sessao> ATIVAS = new ConcurrentHashMap<>();

    private Sessoes() {}

    public record Sessao(String idUsuario, String nome, String login, String idGrupo,
                         String grupo, int nivelAcesso, String idAluno, long expiraEm) {}

    public static String criar(Map<String, Object> u) {
        byte[] b = new byte[24];
        RANDOM.nextBytes(b);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(b);
        ATIVAS.put(token, new Sessao(
                (String) u.get("id_usuario"), (String) u.get("nome"), (String) u.get("login"),
                (String) u.get("id_grupo"), (String) u.get("grupo"),
                ((Number) u.get("nivel_acesso")).intValue(), (String) u.get("id_aluno"),
                System.currentTimeMillis() + DURACAO_MS));
        return token;
    }

    public static Sessao buscar(String token) {
        if (token == null) return null;
        Sessao s = ATIVAS.get(token);
        if (s == null) return null;
        if (s.expiraEm() < System.currentTimeMillis()) {
            ATIVAS.remove(token);
            return null;
        }
        return s;
    }

    public static void encerrar(String token) {
        if (token != null) ATIVAS.remove(token);
    }
}
