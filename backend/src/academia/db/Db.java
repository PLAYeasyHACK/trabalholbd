package academia.db;

import academia.Config;
import java.math.BigDecimal;
import java.sql.*;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class Db {
    private static Config config;
    private static final DateTimeFormatter DATA_HORA = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private Db() {}

    public static void configurar(Config c) { config = c; }

    public static Connection conectar() throws SQLException {
        return DriverManager.getConnection(config.dbUrl, config.dbUsuario, config.dbSenha);
    }

    public static void definirUsuarioApp(Connection c, String idUsuario) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement("SET @usuario_app = ?")) {
            ps.setString(1, idUsuario);
            ps.execute();
        }
    }

    public static List<Map<String, Object>> listar(Connection c, String sql, Object... params) throws SQLException {
        try (PreparedStatement ps = preparar(c, sql, params)) {
            boolean temResultado = ps.execute();
            List<Map<String, Object>> linhas = new ArrayList<>();
            if (!temResultado) return linhas;
            try (ResultSet rs = ps.getResultSet()) {
                ResultSetMetaData md = rs.getMetaData();
                while (rs.next()) {
                    Map<String, Object> linha = new LinkedHashMap<>();
                    for (int i = 1; i <= md.getColumnCount(); i++) {
                        linha.put(md.getColumnLabel(i), converter(rs.getObject(i)));
                    }
                    linhas.add(linha);
                }
            }
            return linhas;
        }
    }

    public static List<Map<String, Object>> listar(String sql, Object... params) throws SQLException {
        try (Connection c = conectar()) {
            return listar(c, sql, params);
        }
    }

    public static Map<String, Object> primeiro(Connection c, String sql, Object... params) throws SQLException {
        List<Map<String, Object>> l = listar(c, sql, params);
        return l.isEmpty() ? null : l.get(0);
    }

    public static Object valor(Connection c, String sql, Object... params) throws SQLException {
        Map<String, Object> linha = primeiro(c, sql, params);
        return linha == null ? null : linha.values().iterator().next();
    }

    public static int executar(Connection c, String sql, Object... params) throws SQLException {
        try (PreparedStatement ps = preparar(c, sql, params)) {
            return ps.executeUpdate();
        }
    }

    private static PreparedStatement preparar(Connection c, String sql, Object... params) throws SQLException {
        PreparedStatement ps = c.prepareStatement(sql);
        for (int i = 0; i < params.length; i++) {
            Object v = params[i];
            if (v instanceof LocalDate d) ps.setDate(i + 1, Date.valueOf(d));
            else ps.setObject(i + 1, v);
        }
        return ps;
    }

    private static Object converter(Object v) {
        if (v == null) return null;
        if (v instanceof Timestamp t) return t.toLocalDateTime().format(DATA_HORA);
        if (v instanceof LocalDateTime t) return t.format(DATA_HORA);
        if (v instanceof Date d) return d.toLocalDate().toString();
        if (v instanceof LocalDate d) return d.toString();
        if (v instanceof Boolean b) return b ? 1 : 0;
        if (v instanceof BigDecimal || v instanceof Number || v instanceof String) return v;
        return v.toString();
    }
}
