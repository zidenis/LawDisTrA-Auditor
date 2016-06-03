import 'package:postgresql/postgresql.dart';
import 'dart:convert';
import 'dart:async';

const String dbURI = "postgresql://procjud:dbpass@localhost:54321/procjud";

class Lawsuit {
  Connection _conn;

  final String codProcesso;
  final String numProcesso;
  final String numDigito;
  final String anoProcesso;
  final String numSegmento;
  final String numTribunal;
  final String numOrigem;
  String dtaAutuacao;
  FaseProcessual faseProcessualAtual;
  List<Parte> partes;
  List<Distribuicao> distribuicoes;
  FaseProcessual faseAtual;
  List<FaseProcessual> fasesAnteriores;

  Lawsuit(String this.codProcesso,
      String this.numProcesso,
      String this.numDigito,
      String this.anoProcesso,
      String this.numSegmento,
      String this.numTribunal,
      String this.numOrigem,
      DateTime dtaAutuacao) {
    if (dtaAutuacao != null) {
      this.dtaAutuacao =
      "${dtaAutuacao.day.toString().padLeft(2, "0")}/${dtaAutuacao.month
          .toString().padLeft(2, "0")}/${dtaAutuacao.year} ${dtaAutuacao.hour
          .toString().padLeft(2, "0")}:${dtaAutuacao.minute.toString().padLeft(
          2, "0")}";
    }
  }

  static Future<Lawsuit> lawsuitFactory(
      Map<String, int> lawsuitIdentification) async {
    Lawsuit lawsuit;
    try {
      Connection conn = await connect(dbURI);
      final sqlQuery = """
                      select cod_processo, num_processo, num_digito, ano_processo,
                             num_segmento, num_tribunal, num_origem, dta_autuacao
                        from t_processo
                       where num_processo = @numero
                         and num_digito = @digito
                         and ano_processo = @ano
                         and num_segmento = 5
                         and num_tribunal = @tribunal
                         and num_origem = @vara
                      """;
      List<Lawsuit> result = (await conn
          .query(sqlQuery, lawsuitIdentification)
          .map((row) => new Lawsuit(
          row.cod_processo,
          row.num_processo,
          row.num_digito,
          row.ano_processo,
          row.num_segmento,
          row.num_tribunal,
          row.num_origem,
          row.dta_autuacao))
          .toList());
      if (result.length > 0) lawsuit = result.first;

      if (lawsuit != null) {
        await lawsuit.getInformacoesComplementares();
      }
      conn.close();
    } catch (exception) {
      print("Erro ao connectar no banco de dados\n${exception.toString()}");
    }
    return lawsuit;
  }

  static Future<Lawsuit> relatedLawsuitFactory(String codProcesso) async {
    Lawsuit lawsuit;
    try {
      Connection conn = await connect(dbURI);
      final sqlQuery = """
                      select cod_processo, num_processo, num_digito, ano_processo,
                             num_segmento, num_tribunal, num_origem, dta_autuacao
                        from t_processo
                       where cod_processo = $codProcesso
                      """;
      List<Lawsuit> result = (await conn
          .query(sqlQuery)
          .map((row) => new Lawsuit(
          row.cod_processo,
          row.num_processo,
          row.num_digito,
          row.ano_processo,
          row.num_segmento,
          row.num_tribunal,
          row.num_origem,
          row.dta_autuacao))
          .toList());

      if (result.length > 0) lawsuit = result.first;

      if (lawsuit != null) {
        await lawsuit.getInformacoesComplementares();
      }
      conn.close();
    } catch (exception) {
      //print("Erro ao connectar no banco de dados\n${exception.toString()}");
    }
    return lawsuit;
  }

  static Future<Lawsuit> summaryLawsuitFactory(String codProcesso) async {
    Lawsuit lawsuit;
    try {
      Connection conn = await connect(dbURI);
      final sqlQuery = """
                      select cod_processo, num_processo, num_digito, ano_processo,
                             num_segmento, num_tribunal, num_origem, dta_autuacao
                        from t_processo
                       where cod_processo = $codProcesso
                      """;
      List<Lawsuit> result = (await conn
          .query(sqlQuery)
          .map((row) => new Lawsuit(
          row.cod_processo,
          row.num_processo,
          row.num_digito,
          row.ano_processo,
          row.num_segmento,
          row.num_tribunal,
          row.num_origem,
          row.dta_autuacao))
          .toList());

      if (result.length > 0) lawsuit = result.first;
      conn.close();
    } catch (exception) {
      print("Erro ao connectar no banco de dados\n${exception.toString()}");
    }
    return lawsuit;
  }

  getInformacoesComplementares() async {
    _conn = await connect(dbURI);
    await _obterFaseAtual();
    await _obterFasesProcessuaisAnteriores();
    await _obterPartesProcesso();
    await _obterDadosDistribuicao();
    _conn.close();
  }

  _obterFaseAtual() async {
    final sqlQuery = """
     select t1.sig_classe, t4.nom_classe, t1.dta_inicio_fase, t1.dta_termino_fase,
            t1.sig_oj, t2.des_oj, t1.cod_magistrado, t3.nom_magistrado
        from t_fase_processual t1
   left join t_orgao_judicante t2
          on t1.sig_oj = t2.sig_oj
   left join t_magistrado t3
          on t1.cod_magistrado = t3.cod_magistrado
   left join t_classe_processual t4
          on t1.sig_classe = t4.sig_classe
       where cod_processo = $codProcesso
         and dta_termino_fase is null
    order by dta_inicio_fase desc
    """;
    faseAtual = (await _conn
        .query(sqlQuery)
        .map((row) => new FaseProcessual(
        row.sig_classe,
        row.nom_classe,
        row.dta_inicio_fase,
        row.dta_termino_fase,
        row.sig_oj,
        row.des_oj,
        row.cod_magistrado,
        row.nom_magistrado))
        .toList())
        .first;
  }

  _obterFasesProcessuaisAnteriores() async {
    final sqlQuery = """
     select t1.sig_classe, t4.nom_classe, t1.dta_inicio_fase, t1.dta_termino_fase,
            t1.sig_oj, t2.des_oj, t1.cod_magistrado, t3.nom_magistrado
        from t_fase_processual t1
   left join t_orgao_judicante t2
          on t1.sig_oj = t2.sig_oj
   left join t_magistrado t3
          on t1.cod_magistrado = t3.cod_magistrado
   left join t_classe_processual t4
          on t1.sig_classe = t4.sig_classe
       where cod_processo = $codProcesso
         and dta_termino_fase is not null
    order by dta_inicio_fase desc
    """;
    fasesAnteriores = await _conn
        .query(sqlQuery)
        .map((row) => new FaseProcessual(
        row.sig_classe,
        row.nom_classe,
        row.dta_inicio_fase,
        row.dta_termino_fase,
        row.sig_oj,
        row.des_oj,
        row.cod_magistrado,
        row.nom_magistrado))
        .toList();
  }

  _obterPartesProcesso() async {
    final sqlQuery = """
    select t1.cod_parte
         , t2.nom_parte
         , case when t4.ind_polo_ativo
                 then (select nom_polo_ativo as txt_den_parte
                         from t_classe_processual tx
                        where t4.sig_classe = tx.sig_classe)
                 else (select nom_polo_passivo as txt_den_parte
                         from t_classe_processual tx
                        where t4.sig_classe = tx.sig_classe)
                end
      from t_processo_parte t1
      join t_parte t2
        on t1.cod_parte = t2.cod_parte
      join t_fase_processual t3
        on t1.cod_processo = t3.cod_processo
      join t_den_parte_fase_proc t4
        on t4.cod_parte = t1.cod_parte
       and t4.cod_processo = t3.cod_processo
       and t4.dta_inicio_fase = t3.dta_inicio_fase
       and t4.sig_classe = t3.sig_classe
     where t1.cod_processo = $codProcesso
       and t3.dta_termino_fase is null
     order by ind_polo_ativo desc;
    """;
    partes = await _conn
        .query(sqlQuery)
        .map(
        (row) => new Parte(row.cod_parte, row.nom_parte, row.txt_den_parte))
        .toList();
    for (Parte parte in partes) {
      await parte.obterAdvogados(_conn, codProcesso);
      await parte.obterProcuradores(_conn, codProcesso);
    }
  }

  _obterDadosDistribuicao() async {
    final sqlQuery = """
      select t1.seq_distribuicao, t1.dta_distribuicao, t2.des_tipo_dist, t1.cod_magistrado,
             t1.sig_oj, t1.txt_regra_aplicada, t1.txt_distribuicao
        from t_hist_distribuicao t1
        join t_tipo_dist t2
          on t1.cod_tipo_dist = t2.cod_tipo_dist
       where cod_processo = $codProcesso
      """;
    distribuicoes = await _conn
        .query(sqlQuery)
        .map((row) => new Distribuicao(
        row.seq_distribuicao,
        row.dta_distribuicao,
        row.des_tipo_dist,
        row.cod_magistrado,
        row.sig_oj,
        row.txt_regra_aplicada,
        row.txt_distribuicao))
        .toList();
    for (Distribuicao distribuicao in distribuicoes) {
      await distribuicao.obterProcessoRelacionado();
    }
  }
}

class FaseProcessual {
  final String sigClasse;
  final String nomClasse;
  final String sigOJ;
  final String desOJ;
  final String codMagistrado;
  final String nomMagistrado;
  String dtaInicioFase;
  String dtaTerminoFase;

  FaseProcessual(this.sigClasse,
      this.nomClasse,
      DateTime dtaInicioFase,
      DateTime dtaTerminoFase,
      this.sigOJ,
      this.desOJ,
      this.codMagistrado,
      this.nomMagistrado) {
    this.dtaInicioFase =
    "${dtaInicioFase.day.toString().padLeft(2, "0")}/${dtaInicioFase.month
        .toString().padLeft(2, "0")}/${dtaInicioFase.year} ${dtaInicioFase.hour
        .toString().padLeft(2, "0")}:${dtaInicioFase.minute.toString().padLeft(
        2, "0")}";
    ;
    if (dtaTerminoFase != null) {
      this.dtaTerminoFase =
      "${dtaTerminoFase.day.toString().padLeft(2, "0")}/${dtaTerminoFase.month
          .toString().padLeft(2, "0")}/${dtaTerminoFase.year} ${dtaTerminoFase
          .hour
          .toString().padLeft(2, "0")}:${dtaTerminoFase.minute.toString()
          .padLeft(
          2, "0")}";
      ;
    }
  }
}

class Parte {
  final String codParte;
  final String nomParte;
  final String txtDenParte;
  List<Advogado> advogados;
  List<Procurador> procuradores;

  Parte(this.codParte, this.nomParte, this.txtDenParte);

  obterAdvogados(Connection conn, String codProcesso) async {
    final sqlQuery = """
    select t1.num_advogado, t1.nom_advogado
      from t_advogado t1
      join t_processo_parte_advogado t2
        on t1.num_advogado = t2.num_advogado
     where t2.cod_parte = $codParte
       and t2.cod_processo = $codProcesso
    """;
    advogados = await conn
        .query(sqlQuery)
        .map((row) => new Advogado(row.num_advogado, row.nom_advogado))
        .toList();
  }

  obterProcuradores(Connection conn, String codProcesso) async {
    final sqlQuery = """
      select t1.num_procurador, t1.nom_procurador
        from t_procurador t1
        join t_processo_parte_procurador t2
          on t1.num_procurador = t2.num_procurador
       where t2.cod_parte = $codParte
         and t2.cod_processo = $codProcesso
    """;
    procuradores = await conn
        .query(sqlQuery)
        .map((row) => new Procurador(row.num_procurador, row.nom_procurador))
        .toList();
  }
}

class Advogado {
  final String numAdvogado;
  final String nomAdvogado;

  Advogado(this.numAdvogado, this.nomAdvogado);
}

class Procurador {
  final String numProcurador;
  final String nomProcurador;

  Procurador(this.numProcurador, this.nomProcurador);
}

class Distribuicao {
  final String seqDistribuicao;
  String dtaDistribuicao;
  final String desTipoDist;
  final String codMagistrado;
  final String sigOj;
  final String txtRegraAplicada;
  String txtDistribuicao;
  String resultado;
  Sorteio sorteio;
  String codProcessoRelacionado;
  Lawsuit processoRelacionado;
  List<Impedimento> impedimentos = new List();

  Distribuicao(this.seqDistribuicao, DateTime dtaDistribuicao, this.desTipoDist,
      this.codMagistrado, this.sigOj, this.txtRegraAplicada, txtDistribuicao) {
    this.dtaDistribuicao =
    "${dtaDistribuicao.day.toString().padLeft(2, "0")}/${dtaDistribuicao.month
        .toString().padLeft(2, "0")}/${dtaDistribuicao.year} ${dtaDistribuicao
        .hour.toString().padLeft(2, "0")}:${dtaDistribuicao.minute.toString()
        .padLeft(2, "0")}";
    switch (desTipoDist) {
      case "Ordinária mediante Sorteio":
        this.resultado = "Processo sorteado para $codMagistrado - $sigOj";
        Map map = JSON.decode(txtDistribuicao)["sorteio"];
        sorteio = new Sorteio(
            ((map["listSigOJsCompetentes"] as List)
              ..sort()).join(", "),
            map["sigOJSorteado"],
            ((map["listCodMagsOJSorteado"] as List)
              ..sort()).join(", "),
            map["codMagistradoSorteado"],
            ((map["magsImpedidos"] as List)
              ..sort()).join(", "));
        List<Map> detalhamentos = JSON.decode(txtDistribuicao)["impedimentos"];
        for (Map detalhamento in detalhamentos) {
          impedimentos.add(new Impedimento(
              detalhamento["codMagistrado"], detalhamento["impedimentosList"]));
        }
        break;

      case "Prevenção":
        this.resultado =
        "Distribuído por prevenção para $codMagistrado - $sigOj";
        break;

      case "Dependência ao Órgão Julgador com sorteio de Magistrado":
        this.resultado =
        "Dependência ao O.J $sigOj com distribuição por sorteio para para $codMagistrado";
        Map map = JSON.decode(txtDistribuicao)["sorteio"];
        sorteio = new Sorteio(
            ((map["listSigOJsCompetentes"] as List)
              ..sort()).join(", "),
            map["sigOJSorteado"],
            ((map["listCodMagsOJSorteado"] as List)
              ..sort()).join(", "),
            map["codMagistradoSorteado"],
            ((map["magsImpedidos"] as List)
              ..sort()).join(", "));
        List<Map> detalhamentos = JSON.decode(txtDistribuicao)["impedimentos"];
        for (Map detalhamento in detalhamentos) {
          impedimentos.add(new Impedimento(
              detalhamento["codMagistrado"], detalhamento["impedimentosList"]));
        }
        break;

      case "Dependência":
        this.resultado =
        "Distribuído para $codMagistrado - $sigOj em razão de dependência com processo relacionado";
        Map map = JSON.decode(txtDistribuicao);
        this.codProcessoRelacionado = map["codProcesso"].toString();
        break;

      case "Não realizada":
        this.resultado = "Distribuição cancelada por impedimento";
        Map map = JSON.decode(txtDistribuicao)["sorteio"];
        sorteio = new Sorteio(
            ((map["listSigOJsCompetentes"] as List)
              ..sort()).join(", "),
            map["sigOJSorteado"],
            ((map["listCodMagsOJSorteado"] as List)
              ..sort()).join(", "),
            map["codMagistradoSorteado"],
            ((map["magsImpedidos"] as List)
              ..sort()).join(", "));
        List<Map> detalhamentos = JSON.decode(txtDistribuicao)["impedimentos"];
        for (Map detalhamento in detalhamentos) {
          impedimentos.add(new Impedimento(
              detalhamento["codMagistrado"], detalhamento["impedimentosList"]));
        }
        break;
    }
  }

  obterProcessoRelacionado() async {
    processoRelacionado =
    await Lawsuit.relatedLawsuitFactory(codProcessoRelacionado);
  }
}

class Sorteio {
  final String listSigOJsCompetentes;
  final String sigOJSorteado;
  final String listCodMagsOJSorteado;
  final String codMagistradoSorteado;
  final String magsImpedidos;

  Sorteio(this.listSigOJsCompetentes,
      this.sigOJSorteado,
      this.listCodMagsOJSorteado,
      this.codMagistradoSorteado,
      this.magsImpedidos);
}

class Impedimento {
  final String codMagistrado;
  final List impedProcesso = new List();
  final List impedAdvogados = new List();
  final List impedPartes = new List();

  Impedimento(this.codMagistrado, impedimentos) {
    for (Map map in impedimentos) {
      if (map.containsKey("numAdvogado")) {
        this.impedAdvogados.add(
            new Advogado(map["numAdvogado"].toString(), map["nomAdvogado"]));
      }
      if (map.containsKey("codParte")) {
        this
            .impedPartes
            .add(new Parte(map["codParte"].toString(), map["nomParte"], ""));
      }
      if (map.containsKey("codProcesso")) {
        this.impedProcesso.add(new Lawsuit(
            map["codProcesso"].toString(),
            map["numProcesso"].toString(),
            map["numDigito"].toString(),
            map["anoProcesso"].toString(),
            map["numSegmento"].toString(),
            map["numTribunal"].toString(),
            map["numOrigem"].toString(),
            null));
      }
    }
  }
}

class Trace {
  final String seqDistribuicao;
  final String codProcesso;
  final Lawsuit lawsuit;
  List<Log> logs;

  Trace(this.seqDistribuicao, this.codProcesso, this.logs, this.lawsuit);

  static Future<Trace> traceFactory(String seqDistribuicao,
      String codProcesso) async {
    try {
      Connection conn = await connect(dbURI);
      final sqlQuery = """
       select row_number() over (ORDER BY dta_informacao) as row_num, dta_informacao, cod_agente, tip_informacao, txt_informacao, txt_detalhes
         from t_info_distribuicao
        where seq_distribuicao = $seqDistribuicao
        order by dta_informacao
                      """;
      List<Log> logs = (await conn
          .query(sqlQuery)
          .map((row) => new Log(
          row.row_num.toString(),
          row.dta_informacao,
          row.cod_agente,
          row.tip_informacao,
          row.txt_informacao,
          row.txt_detalhes))
          .toList());
      conn.close();
      Lawsuit lawsuit = await Lawsuit.summaryLawsuitFactory(codProcesso);
      return new Trace(seqDistribuicao, codProcesso, logs, lawsuit);
    } catch (exception) {
      print(exception.toString());
    }
  }
}

class Log {
  final String rowNum;
  String data;
  String hora;
  final String codAgente;
  String acao;

  Log(this.rowNum, DateTime dtaInformacao, this.codAgente, String tipInformacao,
      String txtInformacao, String txtDetalhes) {
    data =
    "${dtaInformacao.day.toString().padLeft(2, "0")}/${dtaInformacao.month
        .toString().padLeft(2, "0")}/${dtaInformacao.year.toString()}";
    hora =
    "${dtaInformacao.hour.toString().padLeft(2, "0")}:${dtaInformacao.minute
        .toString().padLeft(2, "0")}:${dtaInformacao.second.toString().padLeft(
        2, "0")}.${dtaInformacao.millisecond.toString().padLeft(3, "0")}";
    switch (tipInformacao) {
      case "tarefa":
        acao = "iniciar comportamento <strong>$txtInformacao</strong>";
        break;
      case "mensagem":
        acao =
        "enviar mensagem tipo <strong>$txtInformacao</strong> para o agente <strong>$txtDetalhes</strong>";
        break;
      case "info":
        acao = txtInformacao;
        break;
    }
  }
}
