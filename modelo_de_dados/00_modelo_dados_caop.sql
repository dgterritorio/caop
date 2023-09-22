-- Instalacao de extensoes

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Schema para guardar tabelas de dominios não editaveis a usar como reference em tabelas editaveis
-- talvez faca sentido deixar de fora ou noutro dominio as tabelas de relacao que podem ser editadas,
-- por exemplo as freguesias e concelhos podem ser alteradas as designacoes, ou mesmo necessitar da criação de novos códigos.
-- sendo portanto de alguma forma editaveis e precisam de ter controlo de versões

CREATE SCHEMA dominios;

-- DOMINOS EDITAVEIS
-- criar tabelas de dominios
CREATE TABLE dominios.nut1 (
cod varchar(1) PRIMARY KEY,
designacao varchar NOT NULL
);

CREATE TABLE dominios.nut2 (
cod varchar(2) PRIMARY KEY,
designacao varchar NOT NULL,
cod_nut1 varchar(1) REFERENCES dominios.nut1(cod) NOT NULL -- sugestão relacao com a nut1
);

CREATE TABLE dominios.nut3 (
cod varchar(3) PRIMARY KEY,
designacao varchar NOT NULL,
cod_nut2 varchar(2) REFERENCES dominios.nut2(cod) NOT NULL -- sugestão relacao com a nut2
);

-- duvida sobre se usamos tambem cod ou di, dico e dicofre, ou se isso fica so para as tabelas finais criadas

CREATE TABLE dominios.distrito_ilha (
cod varchar(2) PRIMARY KEY,
designacao varchar NOT NULL,
cod_nut3 varchar(3) REFERENCES dominios.nut3(cod) NOT NULL -- sugestão relacao com a nut3
);

CREATE TABLE dominios.concelho (
cod varchar(4) PRIMARY KEY,
designacao VARCHAR NOT NULL,
distrito varchar(2) REFERENCES dominios.distrito_ilha(cod) NOT NULL -- sugestao relacao com os distritos- ilhas
);
-- criar check constraint the obrigue a que o dico bata certo com o di se este tiver preenchido

-- as entidades administrativas servem para definir em cada troco o que está à direita e o que está à esquerda
-- no entanto isto inclui elemento de tipologias diferente, no freguesias, oceano, rio, e espanha
-- enquanto as freguesias fazem sentido ter uma relacao com os concelhos os restantes noa
-- penso que temos duas alternativas se quiseremos manter estas relacoes ou criamos a tabela abaixo que deixamos a relacao em aberto
-- sem not null. 
CREATE TABLE dominios.entidade_administrativa (
cod VARCHAR(8) primary key, -- para as freguesias isto equivale ao dicofre
designacao VARCHAR not NULL,
concelho varchar(4) references dominios.concelho(cod) -- Sugestao relacao com freguesias mas oceano rio e oceanos nao tem essa relacao
);
-- TODO: Criar check constraint the obrigue a que o dicofre bata certo com o dico se este tiver preenchido

-- Ou então podemos usar inheritance criar uma tabela mae chamada entidade_administrativa que é alimentada por duas tabelas filhas
-- freguesias e outras_entidades_administrativas com alguns campos comuns e outros extra (ligacao aos concelhos)

-- DOMINIOS NAO EDITAVEIS

CREATE TABLE dominios.tipo_fonte (
	cod varchar(3) PRIMARY KEY,
	designacao VARCHAR NOT NULL);

CREATE TABLE dominios.significado_linha
(cod varchar(3) PRIMARY KEY,
designacao VARCHAR NOT NULL);

CREATE TABLE dominios.estado_limite_administrativo
(cod varchar(3) PRIMARY KEY,
designacao VARCHAR NOT NULL);

CREATE TABLE dominios.nivel_limite_administrativo
(cod varchar(3) PRIMARY KEY,
designacao VARCHAR NOT NULL);

CREATE TABLE dominios.tipo_area_administrativa
(cod varchar(3) PRIMARY KEY,
designacao VARCHAR NOT NULL);

CREATE TABLE dominios.caracteres_identificadores_pais
(cod varchar(3) PRIMARY KEY,
designacao VARCHAR NOT NULL);




-- criar tabelas base
CREATE SCHEMA base;

CREATE TABLE base.fontes (
	identificador uuid PRIMARY KEY,
	tipo_fonte varchar(3) REFERENCES dominios.tipo_fonte(cod),
	descricao VARCHAR(255),
	data date, --adicionar DEFAULT para preencher automaticamente
	observacoes VARCHAR,
	diploma VARCHAR(255)
);

CREATE TABLE base.trocos ( -- DUVIDA MANTER OS NOMES FINAIS USADOS nos outputs finais dos trocos?
	identificador uuid PRIMARY KEY,
	ea_direita VARCHAR(8) REFERENCES dominios.entidade_administrativa(cod),
	ea_esquerda VARCHAR(8) REFERENCES dominios.entidade_administrativa(cod),
	pais VARCHAR(3) REFERENCES dominios.caracteres_identificadores_pais(cod), -- ICC manter ou não
	limite_estado VARCHAR(3) REFERENCES dominios.estado_limite_administrativo(cod), --BST manter ou não
	significado_linha VARCHAR(3) REFERENCES dominios.significado_linha(cod), --MOL manter ou não
	limite_nivel VARCHAR(3) REFERENCES dominios.nivel_limite_administrativo, --USE CONFIRMAR COM DGT NECESSIDADE DE RELACAO N:1 talvez precise de tabela à parte
	comprimento_m numeric(15,3),
	fonte uuid REFERENCES base.fontes(identificador), -- relação com a fonte de dados NOT NULL??
	troco_parente uuid, -- para guardar relacao com troco original em caso de cortes 
	             -- tem de ser criada uma referencia para os trocos apagados
	             -- vamos precisar de uma ferramenta especifica para fazer o split
	geometria geometry(LINESTRING, 3763)
);

CREATE TABLE base.centroide_ea ( -- ver se faria sentido AS entidades administrativas terem uma geometria multipoint e pronto! Assunto resolvido!
	identificador uuid PRIMARY KEY,
	entidade_administrativa VARCHAR(8) REFERENCES dominios.entidade_administrativa(cod),
	geometria geometry(POINT, 3763) NOT NULL
);

CREATE SCHEMA VERSIONING;

-- Ideia, adicionar um genero de tag, com uma data especifica para guardar as releases.
-- basicamente uma release é a base de dados um determinado instante, guardar essa data com uma descrições
-- pode ser o suficiente para recuperar/recriar/visualizar a base de dados naquele instante

CREATE TABLE VERSIONING.versoes (
	versao VARCHAR(8) PRIMARY KEY,
	descricao VARCHAR(255) NOT NULL,
	data_hora timestamp DEFAULT now()
);

-- Falta criar uma função que adicione versioning nas tabelas que desejarmos.
-- Guardamos utilizador, timestamp. Falámos em guardar o motivo da alteração, mas ainda não pensei como o fazer


-- Criar grupos de utilizadores
CREATE ROLE administrador; -- sugiro este papel para aqueles que tenham de alterar por exemplo a tabela das entidades
CREATE ROLE editor;
CREATE ROLE visualizador;

