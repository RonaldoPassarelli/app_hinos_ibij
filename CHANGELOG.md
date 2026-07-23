# Changelog

Todas as mudanças relevantes deste projeto serão registradas neste arquivo.

O formato segue as recomendações de [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/), e o projeto utiliza [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não publicado]

### Planejado

- Ampliação dos testes automatizados.
- Interface administrativa para manutenção validada dos hinos.
- Avaliação de suporte a várias igrejas com isolamento de dados.
- Identidade visual e preparação para publicação.

## [1.0.0-beta.1] - 2026-07-23

### Adicionado

- Consulta de hinos por livro e número.
- Pesquisa por assunto.
- Busca aproximada por título e trechos das letras.
- Exibição de tonalidade, assuntos e correspondência entre CC e VM.
- Visualização das estrofes do hino.
- Consulta pública dos cultos planejados e realizados.
- Criação e edição de cultos por usuários autorizados.
- Inclusão, remoção e reordenação dos hinos do culto.
- Escolha da tonalidade de execução.
- Edição de data, horário e observações.
- Classificação automática do culto a partir da data e do horário.
- Autenticação por e-mail e senha.
- Recuperação de senha por e-mail.
- Regras de segurança para leitura pública e escrita restrita.
- Scripts Python para importação controlada e validação das consultas.

### Alterado

- Estrutura dos hinos normalizada para eliminar ambiguidades na correspondência entre livros.
- Busca textual transferida para um índice local otimizado.
- Apresentação das letras simplificada para não classificar refrões como estrofes numeradas.
- Rolagem dos resultados ajustada para apresentar o hino escolhido sem movimentos duplicados.

### Segurança

- Escritas condicionadas a usuário autenticado, ativo e com papel autorizado.
- Credenciais, configurações geradas, exportações e base real excluídas do controle de versão.
