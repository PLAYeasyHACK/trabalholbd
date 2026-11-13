package academia;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

public final class Config {
    public final String dbUrl;
    public final String dbUsuario;
    public final String dbSenha;
    public final int porta;
    public final Path pastaFrontend;

    private Config(Properties p) {
        dbUrl = p.getProperty("db.url",
                "jdbc:mysql://localhost:3306/academia?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=America/Sao_Paulo");
        dbUsuario = p.getProperty("db.usuario", "academia_app");
        dbSenha = p.getProperty("db.senha", "");
        porta = Integer.parseInt(p.getProperty("server.porta", "8080"));
        pastaFrontend = Path.of(p.getProperty("frontend.pasta", "../frontend")).toAbsolutePath().normalize();

        if (dbUsuario.trim().equalsIgnoreCase("root")) {
            throw new IllegalStateException(
                "Por segurança, a aplicação não aceita conectar ao MySQL com o usuário root. "
                + "Use o usuário academia_app.");
        }
    }

    public static Config carregar() throws IOException {
        Path arquivo = Path.of(System.getenv().getOrDefault("ACADEMIA_CONFIG", "db.properties"));
        Properties p = new Properties();
        if (Files.exists(arquivo)) {
            try (InputStreamReader r = new InputStreamReader(new FileInputStream(arquivo.toFile()), StandardCharsets.UTF_8)) {
                p.load(r);
            }
        } else {
            System.out.println("[config] " + arquivo.toAbsolutePath() + " não encontrado; usando valores padrão.");
        }
        return new Config(p);
    }
}
