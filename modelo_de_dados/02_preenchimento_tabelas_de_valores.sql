-- Preenchimento tabelas de domínios

INSERT INTO dominios.tipo_fonte (identificador,descricao,nome) VALUES
	 ('1','Norma jurídica redigida por entidade oficial competente publicada e posteriormente impressa na publicação oficial portuguesa','Lei'),
	 ('2','Ferramenta legislativa usada pelo poder executivo para legislar sobre matéria na qual é competente, sendo obrigatoriamente posterior alvo de publicação no jornal oficial português','Decreto-Lei'),
	 ('3','Ordem publicada no jornal oficial português, que foi emanada por autoridade superior ou órgão que determina o cumprimento de uma resolução','Decreto'),
	 ('4','Documento administrativo de qualquer autoridade pública, publicado no jornal oficial português, que contém instruções acerca da aplicação de leis ou regulamentos, recomendações de carácter geral, normas de execução, nomeações, demissões, punições, ou qualquer outra determinação da sua competência','Portaria'),
	 ('5','Documento administrativo de qualquer autoridade pública, publicado no jornal oficial português, que contém a indicação de alterações, em número reduzido, ao teor de uma lei, decreto-lei, decreto ou outro texto oficial outrora publicado, e na qual se encontram omissões ou incorreções','Retificação'),
	 ('6','Ato de um juiz de um tribunal administrativo português que extingue o processo decidindo determinada questão posta em juízo, decidindo sobre o ato administrativo, resolvendo o conflito de interesses que suscitou a abertura do processo entre as entidades públicas','Acção Administrativa Comum'),
	 ('7','Ato de um juiz de um tribunal administrativo português que extingue o processo decidindo determinada questão posta em juízo, resolvendo o conflito de interesses que suscitou a abertura do processo entre as partes','Sentença de Tribunal Administrativo'),
	 ('8','Conjunto de trabalhos técnicos conducentes ao estabelecimento de um determinado limite administrativo','Procedimento Delimitação Administrativa'),
	 ('9','Dados cartográficos, que foram capturados, manipulados e disponibilizados pelo Instituto Geográfico do Exército, de acordo com as competências legalmente incumbidas a esta instituição','Dados Instituto Geográfico do Exército'),
	 ('10','Dados cartográficos que foram capturados e manipulados pela Direção-Geral do Território, ou por instituição antecedente, com o intuito de caracterizar administrativamente os prédios de acordo com as especificações técnicas definidas para o cadastro geométrico da propriedade rústica','Cadastro Geométrico da Propriedade Rústica'),
	 ('11','Dados cartográficos recolhidos, manipulados e disponibilizados, com finalidade estatística, de acordo com as especificações técnicas estabelecidos para o momento censitário Censos 2001, da responsabilidade do Instituto Nacional de Estatística','Censos 2001'),
	 ('12','Documento administrativo de qualquer autoridade pública, publicado no jornal oficial português, onde constam dados relacionados com outro diploma legal','Declaração'),
	 ('13','Ferramenta legislativa usada pelo poder executivo para legislar sobre matéria na qual é competente, no domínio da autonomia regional, sendo obrigatoriamente posterior alvo de publicação no jornal oficial português','Decreto Legislativo Regional'),
	 ('15','Documento administrativo enviado por uma autarquia, enviado à Direção-Geral do Território, que contém a indicação de alterações a um ou mais troços de limites administrativos da entidade administrativa envolvida','Ofício'),
	 ('14','Dados cartográficos que foram capturados, manipulados e disponibilizados pela Região Autónoma da Madeira, de acordo com as competências legalmente incumbidas a esta instituição','Dados da Direção Regional do Ordenamento do Território e Ambiente (R. A. Madeira)'),
	 ('16','Dados cartográficos que foram capturados, manipulados e disponibilizados pela Região Autónoma da Madeira, de acordo com as competências legalmente incumbidas a esta instituição','Dados da Direção Regional do Ordenamento do Território (R. A. Madeira)'),
	 ('17','Dados cartográficos, que foram capturados, manipulados e disponibilizados pelo Instituto Hidrográfico, de acordo com as competências legalmente incumbidas a esta instituição','Dados do Instituto Hidrográfico');

INSERT INTO dominios.caracteres_identificadores_pais (identificador,descricao,nome) VALUES
	 ('PT','Troço de limite que envolve apenas divisão administrativa em território português','Portugal'),
	 ('PT#ES','Troço de limite que pertence à fronteira internacional entre Portugal e Espanha','Portugal#Espanha');


INSERT INTO dominios.estado_limite_administrativo (identificador,descricao,nome) VALUES
	 ('1','Troço de limite obtido a partir de procedimentos realizados para o efeito.','Definido'),
	 ('2','Troço de limite por definir entre as partes','Por Acordar'),
	 ('3','Troço de limite que não se encontra aceite pelas partes','Não Acordado'),
	 ('4','Troço de limite cuja aceitação pelas partes ainda não foi comunicada oficialmente','Não Confirmado'),
	 ('998','Linha que define exclusivamente parte de um limite, e que se encontra localizado na água','Não Aplicável');

INSERT INTO dominios.nivel_limites_administrativo (identificador,descricao,nome) VALUES
	 ('1','Nível superior da hierarquia administrativa nacional','1ª Ordem'),
	 ('2','Segundo nível na hierarquia administrativa nacional','2ª Ordem'),
	 ('3','Terceiro nível na hierarquia administrativa nacional','3ª Ordem'),
	 ('4','Quarto nível na hierarquia administrativa nacional','4ª Ordem'),
	 ('5','Quinto nível na hierarquia administrativa nacional','5ª Ordem'),
	 ('6','Sexto nível na hierarquia administrativa nacional','6ª Ordem'),
	 ('998','Nível desconhecido ou indefinido','Não Aplicável');

INSERT INTO dominios.significado_linha (identificador,descricao,nome) VALUES
	 ('1','Linha que define, simultaneamente, parte de um limite e de linha de costa','Limite e Linha de Costa'),
	 ('2','Linha que define exclusivamente a linha de costa','Linha de Costa'),
	 ('7','Linha que define um limite que se localiza em terra','Limite em Terra'),
	 ('9','Linha que define um limite que se localiza apenas em massa de água','Limite na Água');

INSERT INTO dominios.tipo_area_administrativa (identificador,descricao,nome, ebm_name) VALUES
	 ('1','Área principal da entidade administrativa, e que coincidirá com a localização da sede de freguesia','Área Principal', 'Main area'),
	 ('3','Área geometricamente separada de uma área principal','Área Secundária','Branch area'),
	 ('4','Área que tem uma competência específica','Área Especial','Special area'),
	 ('5','Área, que engloba uma massa de água, e que se encontra fora de terra','Área Costeira','Coastal water'),
	 ('7','Área que se encontra longe de limites de costa, mas que engloba uma massa de água de grandes dimensões','Área de “Águas Interiores”','Inland water');