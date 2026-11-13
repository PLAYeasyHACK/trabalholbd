package academia.http;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class Json {
    private Json() {}

    public static String escrever(Object v) {
        StringBuilder sb = new StringBuilder();
        escrever(v, sb);
        return sb.toString();
    }

    @SuppressWarnings("unchecked")
    private static void escrever(Object v, StringBuilder sb) {
        if (v == null) sb.append("null");
        else if (v instanceof String s) texto(s, sb);
        else if (v instanceof BigDecimal b) sb.append(b.toPlainString());
        else if (v instanceof Number || v instanceof Boolean) sb.append(v);
        else if (v instanceof Map<?, ?> m) {
            sb.append('{');
            boolean primeiro = true;
            for (Map.Entry<?, ?> e : m.entrySet()) {
                if (!primeiro) sb.append(',');
                primeiro = false;
                texto(String.valueOf(e.getKey()), sb);
                sb.append(':');
                escrever(e.getValue(), sb);
            }
            sb.append('}');
        } else if (v instanceof Iterable<?> it) {
            sb.append('[');
            boolean primeiro = true;
            for (Object o : it) {
                if (!primeiro) sb.append(',');
                primeiro = false;
                escrever(o, sb);
            }
            sb.append(']');
        } else texto(v.toString(), sb);
    }

    private static void texto(String s, StringBuilder sb) {
        sb.append('"');
        for (char c : s.toCharArray()) {
            switch (c) {
                case '"' -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) sb.append(String.format("\\u%04x", (int) c));
                    else sb.append(c);
                }
            }
        }
        sb.append('"');
    }

    public static Object ler(String json) {
        if (json == null || json.isBlank()) return new LinkedHashMap<String, Object>();
        try {
            Leitor l = new Leitor(json);
            Object v = l.valor();
            l.espacos();
            if (l.pos != json.length()) throw new IllegalArgumentException("JSON inválido.");
            return v;
        } catch (IndexOutOfBoundsException | NumberFormatException e) {
            throw new IllegalArgumentException("JSON inválido.");
        }
    }

    private static final class Leitor {
        final String s;
        int pos;

        Leitor(String s) { this.s = s; }

        void espacos() { while (pos < s.length() && Character.isWhitespace(s.charAt(pos))) pos++; }

        Object valor() {
            espacos();
            if (pos >= s.length()) throw new IllegalArgumentException("JSON inválido.");
            char c = s.charAt(pos);
            if (c == '{') return objeto();
            if (c == '[') return lista();
            if (c == '"') return texto();
            if (s.startsWith("true", pos)) { pos += 4; return Boolean.TRUE; }
            if (s.startsWith("false", pos)) { pos += 5; return Boolean.FALSE; }
            if (s.startsWith("null", pos)) { pos += 4; return null; }
            return numero();
        }

        Map<String, Object> objeto() {
            Map<String, Object> m = new LinkedHashMap<>();
            pos++;
            espacos();
            if (s.charAt(pos) == '}') { pos++; return m; }
            while (true) {
                espacos();
                String chave = texto();
                espacos();
                esperar(':');
                m.put(chave, valor());
                espacos();
                if (s.charAt(pos) == ',') { pos++; continue; }
                esperar('}');
                return m;
            }
        }

        List<Object> lista() {
            List<Object> l = new ArrayList<>();
            pos++;
            espacos();
            if (s.charAt(pos) == ']') { pos++; return l; }
            while (true) {
                l.add(valor());
                espacos();
                if (s.charAt(pos) == ',') { pos++; continue; }
                esperar(']');
                return l;
            }
        }

        String texto() {
            esperar('"');
            StringBuilder sb = new StringBuilder();
            while (true) {
                char c = s.charAt(pos++);
                if (c == '"') return sb.toString();
                if (c == '\\') {
                    char e = s.charAt(pos++);
                    switch (e) {
                        case 'n' -> sb.append('\n');
                        case 'r' -> sb.append('\r');
                        case 't' -> sb.append('\t');
                        case 'b' -> sb.append('\b');
                        case 'f' -> sb.append('\f');
                        case 'u' -> { sb.append((char) Integer.parseInt(s.substring(pos, pos + 4), 16)); pos += 4; }
                        default -> sb.append(e);
                    }
                } else sb.append(c);
            }
        }

        Object numero() {
            int inicio = pos;
            while (pos < s.length() && "+-0123456789.eE".indexOf(s.charAt(pos)) >= 0) pos++;
            if (inicio == pos) throw new IllegalArgumentException("JSON inválido.");
            return new BigDecimal(s.substring(inicio, pos));
        }

        void esperar(char c) {
            if (pos >= s.length() || s.charAt(pos) != c) throw new IllegalArgumentException("JSON inválido.");
            pos++;
        }
    }
}
