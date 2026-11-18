import '../../data/models/indicator.dart';

/// Território monitorado pelo app.
///
/// Os dados de clima vêm da API pública Open-Meteo para estas coordenadas.
/// Os demais indicadores são **sintéticos** (gerados de forma determinística
/// pelo serviço simulado), pois não há API pública diária e aberta para eles.
class Territory {
  Territory._();

  static const name = 'Itaquera';
  static const fullName = 'Distrito de Itaquera — Zona Leste, São Paulo/SP';
  static const latitude = -23.5367;
  static const longitude = -46.4558;
  static const population = 204871;
  static const timezone = 'America/Sao_Paulo';

  /// Sub-áreas usadas no formulário de ocorrências (granularidade de bairro,
  /// nunca endereço — reduz risco de reidentificação).
  static const neighborhoods = [
    'Cidade Líder',
    'Colônia',
    'Conjunto José Bonifácio',
    'Itaquera Centro',
    'Jardim Helian',
    'Parque do Carmo',
    'Vila Carmosina',
  ];

  static const historyDays = 60;
  static const forecastDays = 7;
}

/// Catálogo de indicadores monitorados.
class IndicatorCatalog {
  IndicatorCatalog._();

  static const all = <IndicatorDefinition>[
    // ---------------- Recursos ----------------
    IndicatorDefinition(
      id: 'water_consumption',
      domain: TerritoryDomain.resources,
      name: 'Consumo de água',
      shortName: 'Água',
      unit: 'mil m³/dia',
      description:
          'Volume diário de água distribuído no distrito. Picos podem indicar '
          'vazamentos, calor intenso ou desperdício.',
      worseDirection: WorseDirection.higher,
      defaultWarning: 44,
      defaultCritical: 48,
      minPlausible: 0,
      maxPlausible: 200,
      affectedPopulation: 204871,
    ),
    IndicatorDefinition(
      id: 'water_loss',
      domain: TerritoryDomain.resources,
      name: 'Perdas na rede de água',
      shortName: 'Perdas',
      unit: '%',
      description:
          'Percentual da água tratada que se perde antes de chegar ao '
          'consumidor (vazamentos e ligações irregulares).',
      worseDirection: WorseDirection.higher,
      defaultWarning: 34,
      defaultCritical: 38,
      minPlausible: 0,
      maxPlausible: 100,
      affectedPopulation: 204871,
    ),
    IndicatorDefinition(
      id: 'energy_consumption',
      domain: TerritoryDomain.resources,
      name: 'Consumo de energia',
      shortName: 'Energia',
      unit: 'MWh/dia',
      description:
          'Consumo elétrico residencial e comercial agregado do distrito.',
      worseDirection: WorseDirection.higher,
      defaultWarning: 590,
      defaultCritical: 630,
      minPlausible: 0,
      maxPlausible: 5000,
      affectedPopulation: 204871,
      decimals: 0,
    ),
    IndicatorDefinition(
      id: 'energy_outages',
      domain: TerritoryDomain.resources,
      name: 'Interrupções de energia',
      shortName: 'Interrupções',
      unit: 'ocorr./dia',
      description: 'Número de interrupções no fornecimento registradas.',
      worseDirection: WorseDirection.higher,
      defaultWarning: 6,
      defaultCritical: 9,
      minPlausible: 0,
      maxPlausible: 200,
      affectedPopulation: 12000,
      decimals: 0,
    ),
    // ---------------- Clima ----------------
    IndicatorDefinition(
      id: 'temp_max',
      domain: TerritoryDomain.climate,
      name: 'Temperatura máxima',
      shortName: 'Temp. máx.',
      unit: '°C',
      description:
          'Temperatura máxima diária. Calor extremo aumenta risco à saúde de '
          'idosos e crianças e eleva o consumo de água e energia.',
      worseDirection: WorseDirection.higher,
      defaultWarning: 32,
      defaultCritical: 35,
      minPlausible: -10,
      maxPlausible: 50,
      affectedPopulation: 204871,
    ),
    IndicatorDefinition(
      id: 'precipitation',
      domain: TerritoryDomain.climate,
      name: 'Precipitação',
      shortName: 'Chuva',
      unit: 'mm/dia',
      description:
          'Chuva acumulada no dia. Volumes altos elevam risco de alagamentos '
          'em áreas de várzea do distrito.',
      worseDirection: WorseDirection.higher,
      defaultWarning: 30,
      defaultCritical: 50,
      minPlausible: 0,
      maxPlausible: 300,
      affectedPopulation: 35000,
    ),
    IndicatorDefinition(
      id: 'humidity_min',
      domain: TerritoryDomain.climate,
      name: 'Umidade relativa mínima',
      shortName: 'Umidade',
      unit: '%',
      description:
          'Menor umidade relativa do ar no dia. Abaixo de 30% a OMS '
          'recomenda atenção a doenças respiratórias.',
      worseDirection: WorseDirection.lower,
      defaultWarning: 30,
      defaultCritical: 20,
      minPlausible: 0,
      maxPlausible: 100,
      affectedPopulation: 204871,
      decimals: 0,
    ),
    // ---------------- Resíduos ----------------
    IndicatorDefinition(
      id: 'waste_collected',
      domain: TerritoryDomain.waste,
      name: 'Resíduos coletados',
      shortName: 'Coleta',
      unit: 't/dia',
      description: 'Toneladas de resíduos domiciliares coletadas por dia.',
      worseDirection: WorseDirection.higher,
      defaultWarning: 205,
      defaultCritical: 225,
      minPlausible: 0,
      maxPlausible: 2000,
      affectedPopulation: 204871,
      decimals: 0,
    ),
    IndicatorDefinition(
      id: 'irregular_dumping',
      domain: TerritoryDomain.waste,
      name: 'Pontos de descarte irregular',
      shortName: 'Descarte irreg.',
      unit: 'pontos/dia',
      description:
          'Novos pontos de descarte irregular identificados pela zeladoria.',
      worseDirection: WorseDirection.higher,
      defaultWarning: 16,
      defaultCritical: 22,
      minPlausible: 0,
      maxPlausible: 500,
      affectedPopulation: 18000,
      decimals: 0,
    ),
    IndicatorDefinition(
      id: 'recycling_rate',
      domain: TerritoryDomain.waste,
      name: 'Taxa de reciclagem',
      shortName: 'Reciclagem',
      unit: '%',
      description: 'Parcela dos resíduos encaminhada à coleta seletiva.',
      worseDirection: WorseDirection.lower,
      defaultWarning: 6,
      defaultCritical: 4,
      minPlausible: 0,
      maxPlausible: 100,
      affectedPopulation: 204871,
    ),
    // ---------------- Serviços ----------------
    IndicatorDefinition(
      id: 'health_visits',
      domain: TerritoryDomain.services,
      name: 'Atendimentos nas UBS',
      shortName: 'Atend. UBS',
      unit: 'atend./dia',
      description: 'Atendimentos diários nas Unidades Básicas de Saúde.',
      worseDirection: WorseDirection.higher,
      defaultWarning: 1700,
      defaultCritical: 1900,
      minPlausible: 0,
      maxPlausible: 20000,
      affectedPopulation: 60000,
      decimals: 0,
    ),
    IndicatorDefinition(
      id: 'wait_time',
      domain: TerritoryDomain.services,
      name: 'Tempo médio de espera',
      shortName: 'Espera',
      unit: 'min',
      description: 'Tempo médio de espera por atendimento nas UBS.',
      worseDirection: WorseDirection.higher,
      defaultWarning: 60,
      defaultCritical: 80,
      minPlausible: 0,
      maxPlausible: 600,
      affectedPopulation: 60000,
      decimals: 0,
    ),
    IndicatorDefinition(
      id: 'service_requests',
      domain: TerritoryDomain.services,
      name: 'Solicitações de zeladoria (156)',
      shortName: 'Solic. 156',
      unit: 'solic./dia',
      description:
          'Pedidos de manutenção urbana (buracos, iluminação, poda, limpeza).',
      worseDirection: WorseDirection.higher,
      defaultWarning: 120,
      defaultCritical: 150,
      minPlausible: 0,
      maxPlausible: 5000,
      affectedPopulation: 40000,
      decimals: 0,
    ),
  ];

  static IndicatorDefinition byId(String id) =>
      all.firstWhere((d) => d.id == id);

  static List<IndicatorDefinition> byDomain(TerritoryDomain domain) =>
      all.where((d) => d.domain == domain).toList();
}
