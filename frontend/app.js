const estado = { token: null, usuario: null, pagina: null };
const FORMAS = ['Pix', 'Dinheiro', 'Cartão de crédito', 'Cartão de débito'];

const MENU = {
  ADM: [['painel', 'Painel'], ['matriculas', 'Matrículas'], ['alunos', 'Alunos'], ['usuarios', 'Usuários'], ['auditoria', 'Auditoria']],
  REC: [['painel', 'Painel'], ['matriculas', 'Matrículas'], ['alunos', 'Alunos']],
  ALU: [['minhas', 'Minhas matrículas']],
};

const $ = (sel) => document.querySelector(sel);

function esc(v) {
  return String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
const dinheiro = (v) => Number(v ?? 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
function dataBR(v) {
  if (!v) return '';
  const [d, h] = String(v).split(' ');
  const [a, m, dia] = d.split('-');
  return `${dia}/${m}/${a}` + (h ? ' ' + h.slice(0, 5) : '');
}
const tag = (s) => `<span class="tag ${esc(s)}">${esc(s)}</span>`;
const opcoes = (lista, valor, texto) => lista.map((i) => `<option value="${esc(i[valor])}">${esc(texto(i))}</option>`).join('');

function aviso(msg, erro = false) {
  const el = $('#aviso');
  el.textContent = msg;
  el.className = 'aviso' + (erro ? ' erro-aviso' : '');
  clearTimeout(aviso.t);
  aviso.t = setTimeout(() => el.classList.add('oculto'), 4500);
}

async function api(metodo, caminho, corpo) {
  const resp = await fetch(caminho, {
    method: metodo,
    headers: { 'Content-Type': 'application/json', ...(estado.token ? { Authorization: 'Bearer ' + estado.token } : {}) },
    body: corpo ? JSON.stringify(corpo) : undefined,
  });
  const dados = await resp.json().catch(() => ({}));
  if (resp.status === 401 && caminho !== '/api/login') { sair(); }
  if (!resp.ok) throw new Error(dados.erro || 'Erro ' + resp.status);
  return dados;
}

function tabela(linhas, colunas) {
  if (!linhas.length) return '<p class="vazio">Nenhum registro encontrado.</p>';
  const th = colunas.map(([r, , t]) => `<th class="${t || ''}">${esc(r)}</th>`).join('');
  const tr = linhas.map((l) => '<tr>' + colunas.map(([, f, t]) => {
    const v = typeof f === 'function' ? f(l) : esc(l[f]);
    return `<td class="${t || ''}">${v ?? ''}</td>`;
  }).join('') + '</tr>').join('');
  return `<div class="tabela-wrap"><table><thead><tr>${th}</tr></thead><tbody>${tr}</tbody></table></div>`;
}

const card = (titulo, fonte, corpo) =>
  `<div class="card"><h3>${titulo}</h3><p class="fonte">Fonte: ${fonte}</p>${corpo}</div>`;

function dialogo(titulo, camposHtml) {
  return new Promise((resolve) => {
    const d = document.createElement('dialog');
    d.innerHTML = `<form method="dialog" class="form-grade" style="min-width:320px">
        <h3 style="grid-column:1/-1;margin:0">${titulo}</h3>${camposHtml}
        <div class="acoes" style="grid-column:1/-1;justify-content:flex-end">
          <button value="cancelar" class="sec" formnovalidate>Voltar</button><button value="ok">Confirmar</button>
        </div></form>`;
    document.body.appendChild(d);
    d.addEventListener('close', () => {
      const ok = d.returnValue === 'ok';
      const valores = Object.fromEntries(new FormData(d.querySelector('form')));
      d.remove();
      resolve(ok ? valores : null);
    });
    d.showModal();
  });
}

$('#form-login').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('#erro-login').textContent = '';
  const f = new FormData(e.target);
  try {
    const r = await api('POST', '/api/login', { login: f.get('login'), senha: f.get('senha') });
    estado.token = r.token;
    try { sessionStorage.setItem('token', r.token); } catch (_) {}
    await iniciar();
  } catch (err) {
    $('#erro-login').textContent = err.message;
  }
});

$('#btn-sair').addEventListener('click', async () => {
  try { await api('POST', '/api/logout'); } catch (_) {}
  sair();
});

function sair() {
  estado.token = null;
  try { sessionStorage.removeItem('token'); } catch (_) {}
  $('#tela-app').classList.add('oculto');
  $('#tela-login').classList.remove('oculto');
}

async function iniciar() {
  const s = await api('GET', '/api/sessao');
  estado.usuario = s.usuario;
  $('#usuario-nome').textContent = s.usuario.nome;
  $('#usuario-grupo').textContent = s.usuario.grupo;
  $('#db-usuario').textContent = s.conexao.usuario_mysql;
  $('#db-roles').textContent = s.conexao.roles_ativas;
  $('#db-versao').textContent = s.conexao.versao_mysql;

  const itens = MENU[s.usuario.id_grupo] || [];
  $('#menu').innerHTML = itens.map(([id, nome]) => `<a href="#${id}" data-pag="${id}">${nome}</a>`).join('');
  $('#tela-login').classList.add('oculto');
  $('#tela-app').classList.remove('oculto');

  const inicial = location.hash.slice(1);
  abrir(itens.some(([id]) => id === inicial) ? inicial : itens[0][0]);
}

window.addEventListener('hashchange', () => {
  const p = location.hash.slice(1);
  if (estado.usuario && PAGINAS[p]) abrir(p);
});

async function abrir(pagina) {
  estado.pagina = pagina;
  document.querySelectorAll('#menu a').forEach((a) => a.classList.toggle('ativo', a.dataset.pag === pagina));
  if (location.hash.slice(1) !== pagina) history.replaceState(null, '', '#' + pagina);
  const main = $('#conteudo');
  main.innerHTML = '<p class="vazio">Carregando…</p>';
  try {
    await PAGINAS[pagina](main);
  } catch (err) {
    main.innerHTML = `<div class="card"><p class="erro">${esc(err.message)}</p></div>`;
  }
}

const PAGINAS = {

  async painel(main) {
    const p = await api('GET', '/api/painel');
    const emDia = p.resumo.reduce((s, r) => s + Number(r.em_dia), 0);
    const atrasadas = p.resumo.reduce((s, r) => s + Number(r.atrasadas), 0);
    const prevista = p.resumo.reduce((s, r) => s + Number(r.receita_mensal_prevista), 0);
    const recebidoMes = p.receita[0] ? p.receita[0].total_recebido : 0;

    main.innerHTML = `<h2>Painel</h2>
      <div class="numeros">
        <div class="numero"><div class="rotulo">Matrículas em dia</div><div class="valor">${emDia}</div></div>
        <div class="numero"><div class="rotulo">Matrículas atrasadas</div><div class="valor">${atrasadas}</div></div>
        <div class="numero"><div class="rotulo">Receita mensal prevista</div><div class="valor">${dinheiro(prevista)}</div></div>
        <div class="numero"><div class="rotulo">Recebido no último mês</div><div class="valor">${dinheiro(recebidoMes)}</div></div>
      </div>
      ${card('Resumo por modalidade', 'VIEW <code>vw_resumo_modalidades</code>', tabela(p.resumo, [
        ['Modalidade', 'modalidade'], ['Preço atual', (r) => dinheiro(r.preco_atual), 'num'],
        ['Em dia', 'em_dia', 'num'], ['Atrasadas', 'atrasadas', 'num'], ['Suspensas', 'suspensas', 'num'],
        ['Receita prevista/mês', (r) => dinheiro(r.receita_mensal_prevista), 'num']]))}
      ${card('Inadimplentes', 'VIEW <code>vw_inadimplentes</code> (construída sobre <code>vw_matriculas_detalhadas</code>)', tabela(p.inadimplentes, [
        ['Matrícula', 'id_matricula'], ['Aluno', 'aluno'], ['Telefone', 'telefone'], ['Modalidade', 'modalidade'],
        ['Venceu em', (r) => dataBR(r.data_vencimento)], ['Dias em atraso', 'dias_em_atraso', 'num'],
        ['Mensalidade', (r) => dinheiro(r.valor_mensal), 'num']]))}
      ${card('Receita realizada por mês', 'VIEW <code>vw_receita_mensal</code>', tabela(p.receita, [
        ['Mês', 'mes'], ['Pagamentos', 'qtd_pagamentos', 'num'], ['Total recebido', (r) => dinheiro(r.total_recebido), 'num']]))}`;
  },

  async matriculas(main) {
    const [alunos, modalidades, planos, professores] = await Promise.all([
      api('GET', '/api/alunos'), api('GET', '/api/modalidades'), api('GET', '/api/planos'), api('GET', '/api/professores')]);

    main.innerHTML = `<h2>Matrículas</h2>
      <div class="card"><h3>Nova matrícula</h3>
        <p class="fonte">Grava pela PROCEDURE <code>sp_contratar_matricula</code> (matrícula + 1º pagamento numa única transação).
          Valor calculado pela FUNCTION <code>fn_valor_total_plano</code>.</p>
        <form id="form-mat" class="form-grade">
          <label>Aluno<select name="id_aluno" required><option value="">Selecione</option>${opcoes(alunos, 'id_aluno', (a) => a.nome)}</select></label>
          <label>Modalidade<select name="id_modalidade" required><option value="">Selecione</option>${opcoes(modalidades, 'id_modalidade', (m) => `${m.nome} (${dinheiro(m.valor_mensal)}/mês)`)}</select></label>
          <label>Plano<select name="id_plano" required><option value="">Selecione</option>${opcoes(planos, 'id_plano', (p) => `${p.nome} - ${Number(p.desconto_percentual)}% desc.`)}</select></label>
          <label>Professor<select name="id_professor" required><option value="">Selecione</option>${opcoes(professores, 'id_professor', (p) => p.nome)}</select></label>
          <label>Forma de pagamento<select name="forma">${FORMAS.map((f) => `<option>${f}</option>`).join('')}</select></label>
          <label>Valor a pagar<input id="valor-simulado" readonly placeholder="—"></label>
          <button type="submit">Contratar</button>
        </form>
      </div>
      <div class="card"><h3>Relatório de matrículas</h3>
        <p class="fonte">PROCEDURE <code>sp_relatorio_matriculas</code>, que lê a VIEW <code>vw_matriculas_detalhadas</code></p>
        <form id="form-filtro" class="form-grade" style="margin-bottom:14px">
          <label>Início a partir de<input type="date" name="inicio"></label>
          <label>Início até<input type="date" name="fim"></label>
          <label>Situação<select name="situacao"><option value="">Todas</option>
            <option>Ativa</option><option>Atrasada</option><option>Suspensa</option><option>Cancelada</option></select></label>
          <button type="submit" class="sec">Filtrar</button>
        </form>
        <div id="lista-mat"></div>
      </div>`;

    const formMat = $('#form-mat');
    formMat.addEventListener('change', async () => {
      const f = new FormData(formMat);
      if (!f.get('id_modalidade') || !f.get('id_plano')) return;
      const r = await api('GET', `/api/simular?modalidade=${f.get('id_modalidade')}&plano=${f.get('id_plano')}`);
      $('#valor-simulado').value = dinheiro(r.valor_total);
    });
    formMat.addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        const r = await api('POST', '/api/matriculas', Object.fromEntries(new FormData(formMat)));
        aviso(`Matrícula ${r.id_matricula} criada. Pagamento ${r.id_pagamento} registrado (COMMIT).`);
        formMat.reset();
        $('#valor-simulado').value = '';
        carregar();
      } catch (err) { aviso(err.message, true); }
    });

    const formFiltro = $('#form-filtro');
    formFiltro.addEventListener('submit', (e) => { e.preventDefault(); carregar(); });

    async function carregar() {
      const q = new URLSearchParams(Object.entries(Object.fromEntries(new FormData(formFiltro))).filter(([, v]) => v));
      const linhas = await api('GET', '/api/matriculas?' + q);
      $('#lista-mat').innerHTML = tabela(linhas, [
        ['Matrícula', 'id_matricula'], ['Aluno', 'aluno'], ['Modalidade', 'modalidade'], ['Plano', 'plano'],
        ['Professor', 'professor'], ['Início', (r) => dataBR(r.data_inicio)], ['Vencimento', (r) => dataBR(r.data_vencimento)],
        ['Mensal', (r) => dinheiro(r.valor_mensal), 'num'], ['Situação', (r) => tag(r.situacao_atual)],
        ['Ações', (r) => r.situacao === 'Cancelada' ? '' : `<div class="acoes">
            <button class="mini" data-pagar="${esc(r.id_matricula)}">Pagamento</button>
            <button class="mini perigo" data-cancelar="${esc(r.id_matricula)}">Cancelar</button></div>`]]);
    }
    $('#lista-mat').addEventListener('click', async (e) => {
      const pagar = e.target.dataset.pagar, cancelar = e.target.dataset.cancelar;
      try {
        if (pagar) {
          const v = await dialogo(`Registrar pagamento — ${esc(pagar)}`,
            `<p class="fonte" style="grid-column:1/-1">PROCEDURE <code>sp_registrar_pagamento</code>: INSERT do pagamento + UPDATE do vencimento na mesma transação.</p>
             <label style="grid-column:1/-1">Forma<select name="forma">${FORMAS.map((f) => `<option>${f}</option>`).join('')}</select></label>`);
          if (!v) return;
          const r = await api('POST', `/api/matriculas/${encodeURIComponent(pagar)}/pagamentos`, v);
          aviso(`Pagamento ${r.id_pagamento} registrado e vencimento renovado.`);
        }
        if (cancelar) {
          const v = await dialogo(`Cancelar matrícula — ${esc(cancelar)}`,
            `<label style="grid-column:1/-1">Motivo (vai para a auditoria)<input name="motivo"></label>`);
          if (!v) return;
          await api('POST', `/api/matriculas/${encodeURIComponent(cancelar)}/cancelar`, v);
          aviso('Matrícula cancelada.');
        }
        if (pagar || cancelar) carregar();
      } catch (err) { aviso(err.message, true); }
    });
    carregar();
  },

  async alunos(main) {
    main.innerHTML = `<h2>Alunos</h2>
      <div class="card"><h3>Cadastrar aluno</h3>
        <p class="fonte">Transação no Java: INSERT em <code>usuarios</code> + INSERT em <code>aluno</code>, com
          <code>commit()</code> ou <code>rollback()</code>. O login do aluno é o CPF.</p>
        <form id="form-aluno" class="form-grade">
          <label>Nome<input name="nome" required></label>
          <label>CPF<input name="cpf" required placeholder="000.000.000-00"></label>
          <label>Telefone<input name="telefone"></label>
          <label>E-mail<input name="email" type="email"></label>
          <label>Nascimento<input name="data_nascimento" type="date"></label>
          <label>Senha inicial<input name="senha" type="password" required></label>
          <button type="submit">Cadastrar</button>
        </form>
      </div>
      <div class="card"><h3>Alunos cadastrados</h3>
        <p class="fonte">TABELA <code>aluno</code> (busca por nome usa o índice <code>idx_aluno_nome</code>)</p>
        <form id="form-busca" class="form-grade" style="margin-bottom:14px">
          <label>Buscar pelo início do nome<input name="busca"></label>
          <button class="sec">Buscar</button>
        </form>
        <div id="lista-alunos"></div>
      </div>`;

    const carregar = async () => {
      const busca = new FormData($('#form-busca')).get('busca') || '';
      const linhas = await api('GET', '/api/alunos?busca=' + encodeURIComponent(busca));
      $('#lista-alunos').innerHTML = tabela(linhas, [
        ['ID', 'id_aluno'], ['Nome', 'nome'], ['CPF', 'cpf'], ['Telefone', 'telefone'], ['E-mail', 'email'],
        ['Nascimento', (r) => dataBR(r.data_nascimento)], ['Usuário', 'id_usuario'], ['Cadastro', (r) => dataBR(r.criado_em)]]);
    };
    $('#form-busca').addEventListener('submit', (e) => { e.preventDefault(); carregar(); });
    $('#form-aluno').addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        const r = await api('POST', '/api/alunos', Object.fromEntries(new FormData(e.target)));
        aviso(`Aluno ${r.id_aluno} cadastrado (usuário ${r.id_usuario}). Transação: ${r.transacao}.`);
        e.target.reset();
        carregar();
      } catch (err) { aviso(err.message + ' — transação desfeita (ROLLBACK).', true); }
    });
    carregar();
  },

  async usuarios(main) {
    main.innerHTML = '<h2>Usuários e grupos</h2><div id="area-usuarios"></div>';
    const area = $('#area-usuarios');
    const carregar = async () => {
      const linhas = await api('GET', '/api/usuarios');
      area.innerHTML = `${card('Usuários do sistema', 'VIEW <code>vw_usuarios_seguro</code> (sem a coluna senha_hash) + tabela <code>grupos_usuarios</code>', tabela(linhas, [
          ['ID', 'id_usuario'], ['Nome', 'nome'], ['Login', 'login'], ['Grupo', (r) => `${esc(r.grupo)} (nível ${r.nivel_acesso})`],
          ['Situação', (r) => (r.ativo == 1 ? tag('Ativa').replace('Ativa', 'Ativo') : tag('Cancelada').replace('Cancelada', 'Inativo'))],
          ['Último acesso', (r) => dataBR(r.ultimo_acesso)],
          ['', (r) => `<button class="mini sec" data-id="${esc(r.id_usuario)}" data-ativo="${r.ativo == 1 ? 0 : 1}">${r.ativo == 1 ? 'Desativar' : 'Reativar'}</button>`]]))}`;
    };
    area.addEventListener('click', async (e) => {
      const id = e.target.dataset.id;
      if (!id) return;
      try {
        await api('POST', `/api/usuarios/${id}/ativo`, { ativo: e.target.dataset.ativo === '1' });
        aviso('Usuário atualizado. A trigger trg_usuarios_au gravou na auditoria.');
        carregar();
      } catch (err) { aviso(err.message, true); }
    });
    await carregar();
  },

  async auditoria(main) {
    const linhas = await api('GET', '/api/auditoria');
    main.innerHTML = `<h2>Auditoria</h2>
      ${card('Últimos eventos', 'TABELA <code>log_auditoria</code>, gravada automaticamente pelas triggers', tabela(linhas, [
        ['#', 'id_log', 'num'], ['Data/hora', (r) => dataBR(r.data_hora)], ['Tabela', 'tabela'], ['Operação', 'operacao'],
        ['Registro', 'id_registro'], ['Detalhes', 'detalhes'], ['Usuário MySQL', 'usuario_banco'], ['Usuário app', 'usuario_app']]))}`;
  },

  async minhas(main) {
    const [linhas, modalidades, planos, professores] = await Promise.all([
      api('GET', '/api/minhas-matriculas'), api('GET', '/api/modalidades'), api('GET', '/api/planos'), api('GET', '/api/professores')]);
    main.innerHTML = `<h2>Olá, ${esc(estado.usuario.nome.split(' ')[0])}</h2>
      ${card('Minhas matrículas', 'VIEW <code>vw_matriculas_detalhadas</code> filtrada pelo aluno logado', tabela(linhas, [
        ['Matrícula', 'id_matricula'], ['Modalidade', 'modalidade'], ['Plano', 'plano'], ['Professor', 'professor'],
        ['Vencimento', (r) => dataBR(r.data_vencimento)], ['Situação', (r) => tag(r.situacao_atual)],
        ['', (r) => r.situacao === 'Cancelada' ? '' : `<button class="mini perigo" data-cancelar="${esc(r.id_matricula)}">Cancelar</button>`]]))}
      <div class="card"><h3>Contratar nova modalidade</h3>
        <p class="fonte">PROCEDURE <code>sp_contratar_matricula</code></p>
        <form id="form-contratar" class="form-grade">
          <label>Modalidade<select name="id_modalidade" required><option value="">Selecione</option>${opcoes(modalidades, 'id_modalidade', (m) => `${m.nome} (${dinheiro(m.valor_mensal)}/mês)`)}</select></label>
          <label>Plano<select name="id_plano" required><option value="">Selecione</option>${opcoes(planos, 'id_plano', (p) => p.nome)}</select></label>
          <label>Professor<select name="id_professor" required><option value="">Selecione</option>${opcoes(professores, 'id_professor', (p) => p.nome)}</select></label>
          <label>Pagamento<select name="forma">${FORMAS.map((f) => `<option>${f}</option>`).join('')}</select></label>
          <label>Valor<input id="valor-aluno" readonly placeholder="—"></label>
          <button>Contratar</button>
        </form>
      </div>`;
    const form = $('#form-contratar');
    form.addEventListener('change', async () => {
      const f = new FormData(form);
      if (!f.get('id_modalidade') || !f.get('id_plano')) return;
      const r = await api('GET', `/api/simular?modalidade=${f.get('id_modalidade')}&plano=${f.get('id_plano')}`);
      $('#valor-aluno').value = dinheiro(r.valor_total);
    });
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        const r = await api('POST', '/api/matriculas', Object.fromEntries(new FormData(form)));
        aviso(`Matrícula ${r.id_matricula} contratada!`);
        abrir('minhas');
      } catch (err) { aviso(err.message, true); }
    });
    main.querySelector('table')?.addEventListener('click', async (e) => {
      const id = e.target.dataset.cancelar;
      if (!id) return;
      const v = await dialogo('Cancelar matrícula', `<label style="grid-column:1/-1">Motivo<input name="motivo"></label>`);
      if (!v) return;
      try {
        await api('POST', `/api/matriculas/${encodeURIComponent(id)}/cancelar`, v);
        aviso('Matrícula cancelada.');
        abrir('minhas');
      } catch (err) { aviso(err.message, true); }
    });
  },
};

(async () => {
  try { estado.token = sessionStorage.getItem('token'); } catch (_) {}
  if (estado.token) {
    try { await iniciar(); } catch (_) { sair(); }
  }
})();
