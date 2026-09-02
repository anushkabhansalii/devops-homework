import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpExchange;
import java.io.OutputStream;
import java.net.InetSocketAddress;

public class HelloServer {
    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        server.createContext("/", (HttpExchange ex) -> {
            String body = "<h1>Hello World from Java in Docker</h1>";
            ex.getResponseHeaders().add("Content-Type", "text/html");
            ex.sendResponseHeaders(200, body.length());
            try (OutputStream os = ex.getResponseBody()) { os.write(body.getBytes()); }
        });
        System.out.println("Java app running on port 8080");
        server.start();
    }
}
