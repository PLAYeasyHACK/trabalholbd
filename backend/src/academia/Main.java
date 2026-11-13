package academia;

import academia.db.Db;
import academia.http.Api;
import academia.http.Arquivos;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.concurrent.Executors;

public class Main {
    public static void main(String[] args) throws Exception {
        Config config = Config.carregar();
        Db.configurar(config);

        try (Connection c = Db.conectar(); Statement st = c.createStatement();
             ResultSet rs = st.executeQuery("SELECT CURRENT_USER(), CURRENT_ROLE()")) {
            rs.next();
            System.out.println("[banco] Conectado como " + rs.getString(1) + " | roles: " + rs.getString(2));
        } catch (Exception e) {
            System.out.println("[banco] ATENÇÃO: não foi possível conectar ao MySQL: " + e.getMessage());
            System.out.println("[banco] Confira se o script sql/academia.sql foi executado e o db.properties.");
        }

        HttpServer server = HttpServer.create(new InetSocketAddress(config.porta), 0);
        server.createContext("/api/", new Api());
        server.createContext("/", new Arquivos(config.pastaFrontend));
        server.setExecutor(Executors.newFixedThreadPool(8));
        server.start();
        System.out.println("[web] Aplicação rodando em http://localhost:" + config.porta);
        System.out.println("[web] Frontend servido de " + config.pastaFrontend);
    }
}
