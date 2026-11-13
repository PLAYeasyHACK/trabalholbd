package academia.dao;

import academia.db.Db;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public class MatriculaDAO {

    public List<Map<String, Object>> relatorio(LocalDate inicio, LocalDate fim, String situacao) throws SQLException {
        try (Connection c = Db.conectar()) {
            return Db.listar(c, "CALL sp_relatorio_matriculas(?, ?, ?)", inicio, fim, situacao);
        }
    }

    public List<Map<String, Object>> doAluno(String idAluno) throws SQLException {
        return Db.listar("SELECT * FROM vw_matriculas_detalhadas WHERE id_aluno = ? "
                       + "ORDER BY data_inicio DESC", idAluno);
    }

    public boolean pertenceAoAluno(String idMatricula, String idAluno) throws SQLException {
        try (Connection c = Db.conectar()) {
            return Db.primeiro(c, "SELECT 1 FROM vw_matriculas_detalhadas WHERE id_matricula = ? AND id_aluno = ?",
                    idMatricula, idAluno) != null;
        }
    }

    public Map<String, Object> contratar(String idAluno, int idModalidade, int idPlano, String idProfessor,
                                         String forma, String idUsuarioLogado) throws SQLException {
        try (Connection c = Db.conectar()) {
            Db.executar(c, "CALL sp_contratar_matricula(?, ?, ?, ?, ?, ?, @id_mat, @id_pag)",
                    idAluno, idModalidade, idPlano, idProfessor, forma, idUsuarioLogado);
            return Db.primeiro(c, "SELECT @id_mat AS id_matricula, @id_pag AS id_pagamento");
        }
    }

    public Map<String, Object> registrarPagamento(String idMatricula, String forma, String idUsuarioLogado)
            throws SQLException {
        try (Connection c = Db.conectar()) {
            Db.executar(c, "CALL sp_registrar_pagamento(?, ?, ?, @id_pag)", idMatricula, forma, idUsuarioLogado);
            return Db.primeiro(c, "SELECT @id_pag AS id_pagamento");
        }
    }

    public void cancelar(String idMatricula, String motivo, String idUsuarioLogado) throws SQLException {
        try (Connection c = Db.conectar()) {
            Db.executar(c, "CALL sp_cancelar_matricula(?, ?, ?)", idMatricula, motivo, idUsuarioLogado);
        }
    }
}
