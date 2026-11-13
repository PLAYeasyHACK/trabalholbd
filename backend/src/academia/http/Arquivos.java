package academia.http;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

public class Arquivos implements HttpHandler {
    private static final Map<String, String> TIPOS = Map.of(
            "html", "text/html; charset=utf-8",
            "css", "text/css; charset=utf-8",
            "js", "application/javascript; charset=utf-8",
            "svg", "image/svg+xml",
            "png", "image/png",
            "ico", "image/x-icon");

    private final Path raiz;

    public Arquivos(Path raiz) { this.raiz = raiz; }

    @Override
    public void handle(HttpExchange ex) throws IOException {
        String caminho = ex.getRequestURI().getPath();
        if (caminho.equals("/")) caminho = "/index.html";
        Path arquivo = raiz.resolve(caminho.substring(1)).normalize();

        if (!arquivo.startsWith(raiz) || !Files.isRegularFile(arquivo)) {
            byte[] msg = "404 - arquivo não encontrado".getBytes();
            ex.sendResponseHeaders(404, msg.length);
            try (OutputStream os = ex.getResponseBody()) { os.write(msg); }
            return;
        }
        String nome = arquivo.getFileName().toString();
        String ext = nome.substring(nome.lastIndexOf('.') + 1).toLowerCase();
        byte[] conteudo = Files.readAllBytes(arquivo);
        ex.getResponseHeaders().set("Content-Type", TIPOS.getOrDefault(ext, "application/octet-stream"));
        ex.sendResponseHeaders(200, conteudo.length);
        try (OutputStream os = ex.getResponseBody()) { os.write(conteudo); }
    }
}
