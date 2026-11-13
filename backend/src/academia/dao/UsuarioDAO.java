package academia.dao;

import academia.db.Db;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

public class UsuarioDAO {

    public Map<String, Object> autenticar(String login, String senhaHash) throws SQLException {
        try (Connection c = Db.conectar()) {
            return Db.primeiro(c, "CALL sp_autenticar(?, ?)", login, senhaHash);
        }
    }

    public List<Map<String, Object>> listar() throws SQLException {
        return Db.listar("SELECT * FROM vw_usuarios_seguro ORDER BY nivel_acesso DESC, nome");
    }

    public void alterarAtivo(String idUsuario, boolean ativo, String idUsuarioLogado) throws SQLException {
        try (Connection c = Db.conectar()) {
            Db.definirUsuarioApp(c, idUsuarioLogado);
            int n = Db.executar(c, "UPDATE usuarios SET ativo = ? WHERE id_usuario = ?", ativo ? 1 : 0, idUsuario);
            if (n == 0) throw new IllegalArgumentException("Usuário não encontrado.");
        }
    }

    public List<Map<String, Object>> auditoria() throws SQLException {
        return Db.listar("SELECT * FROM log_auditoria ORDER BY id_log DESC LIMIT 200");
    }

    public Map<String, Object> infoConexao() throws SQLException {
        try (Connection c = Db.conectar()) {
            return Db.primeiro(c,
                "SELECT CURRENT_USER() AS usuario_mysql, CURRENT_ROLE() AS roles_ativas, "
                + "DATABASE() AS banco, VERSION() AS versao_mysql");
        }
    }
}
