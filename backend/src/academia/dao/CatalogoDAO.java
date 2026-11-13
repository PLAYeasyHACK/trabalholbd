package academia.dao;

import academia.db.Db;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

public class CatalogoDAO {

    public List<Map<String, Object>> modalidades() throws SQLException {
        return Db.listar("SELECT id_modalidade, nome, descricao, valor_mensal FROM modalidade WHERE ativa = 1 ORDER BY nome");
    }

    public List<Map<String, Object>> planos() throws SQLException {
        return Db.listar("SELECT id_plano, nome, duracao_meses, desconto_percentual FROM plano ORDER BY duracao_meses");
    }

    public List<Map<String, Object>> professores() throws SQLException {
        return Db.listar("SELECT id_professor, nome, telefone, cref FROM professor WHERE ativo = 1 ORDER BY nome");
    }

    public Object simularValor(int idModalidade, int idPlano) throws SQLException {
        try (Connection c = Db.conectar()) {
            return Db.valor(c, "SELECT fn_valor_total_plano(?, ?)", idModalidade, idPlano);
        }
    }

    public boolean idValido(String id) throws SQLException {
        try (Connection c = Db.conectar()) {
            Object v = Db.valor(c, "SELECT fn_id_valido(?)", id);
            return v != null && ((Number) v).intValue() == 1;
        }
    }

    public List<Map<String, Object>> resumoModalidades() throws SQLException {
        return Db.listar("SELECT * FROM vw_resumo_modalidades ORDER BY modalidade");
    }

    public List<Map<String, Object>> receitaMensal() throws SQLException {
        return Db.listar("SELECT * FROM vw_receita_mensal ORDER BY mes DESC LIMIT 12");
    }

    public List<Map<String, Object>> inadimplentes() throws SQLException {
        return Db.listar("SELECT * FROM vw_inadimplentes ORDER BY dias_em_atraso DESC");
    }
}
