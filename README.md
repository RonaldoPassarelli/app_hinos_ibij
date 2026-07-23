# Hinos IBIJ

Aplicativo multiplataforma desenvolvido em Flutter para consulta de hinos e planejamento de cultos, com autenticação e persistência de dados no Firebase.

> Estado do projeto: versão beta funcional, em testes de uso real.

## Visão geral

O Hinos IBIJ centraliza a pesquisa dos hinários Cantor Cristão (CC) e Voz de Melodia (VM), identifica correspondências entre os livros e auxilia a organização das músicas de cada culto.

As consultas são públicas. A criação e a edição de cultos são reservadas a usuários autorizados.

## Funcionalidades

- Pesquisa de hinos por livro e número.
- Pesquisa por assunto.
- Busca aproximada por título ou trecho da letra.
- Exibição da tonalidade, dos assuntos e do correspondente no outro hinário.
- Visualização das estrofes para conferência da música.
- Consulta do último uso do hino.
- Criação e edição de cultos por usuários autorizados.
- Inclusão, remoção e reordenação dos hinos de um culto.
- Escolha de tonalidade específica para cada execução.
- Edição de data, horário e observações do culto.
- Classificação automática entre cultos planejados e realizados.
- Recuperação de senha por e-mail.

## Tecnologias

| Componente | Tecnologia |
|---|---|
| Interface e aplicação | Flutter / Dart |
| Autenticação | Firebase Authentication |
| Banco de dados | Cloud Firestore |
| Regras de acesso | Firebase Security Rules |
| Preparação e validação de dados | Python |

Consulte [ARCHITECTURE.md](ARCHITECTURE.md) para conhecer a organização técnica e os principais fluxos do aplicativo.

## Segurança e dados

Este repositório não contém:

- credenciais ou chaves de contas de serviço;
- arquivos de configuração Firebase gerados para o ambiente de produção;
- exportações do Cloud Firestore;
- a base completa de hinos;
- o índice real de busca, que contém conteúdo derivado da base.

O arquivo `assets/indice_busca_hinos.example.json` apresenta somente a estrutura esperada, com dados fictícios.

As regras do Firestore permitem consulta pública às informações necessárias ao aplicativo e restringem operações de escrita a usuários ativos com papel de editor ou administrador.

## Preparação do ambiente

### Pré-requisitos

- Flutter compatível com o SDK definido em `pubspec.yaml`;
- Firebase CLI;
- FlutterFire CLI;
- projeto Firebase próprio com Authentication e Cloud Firestore.

### Instalação

```powershell
git clone <URL-DO-REPOSITORIO>
cd app_hinos_ibij
flutter pub get
Copy-Item .\assets\indice_busca_hinos.example.json .\assets\indice_busca_hinos.json
flutterfire configure
flutter run
```

No Firebase Authentication, habilite o provedor de e-mail e senha. Crie também o banco Cloud Firestore para o projeto utilizado no ambiente local.

Para publicar as regras de segurança:

```powershell
firebase deploy --only firestore:rules
```

## Índice local de pesquisa

A busca aproximada usa `assets/indice_busca_hinos.json`, gerado a partir da base autorizada para o aplicativo. Cada registro possui:

- `id`
- `livro`
- `numeroFormatado`
- `titulo`
- `tom`
- `tituloNormalizado`
- `textoBusca`

O arquivo real deve ser fornecido separadamente e não deve ser enviado ao repositório.

## Ferramentas de dados

Os utilitários em `tools/` auxiliam a validação e a importação controlada:

```powershell
# Somente valida o arquivo, sem acessar ou alterar o Firestore
python .\tools\importar_firestore.py .\caminho\hinos.json

# Importa explicitamente para uma coleção de teste
python .\tools\importar_firestore.py .\caminho\hinos.json --colecao hinos_teste --executar

# Executa consultas de validação sem modificar documentos
python .\tools\testar_firestore.py --colecao hinos_teste
```

Os scripts usam a variável de ambiente `GOOGLE_APPLICATION_CREDENTIALS`. O arquivo de credenciais deve permanecer fora do repositório.

## Verificação

Antes de cada entrega:

```powershell
flutter analyze
```

Os testes automatizados ainda serão reestruturados para refletir os fluxos reais do aplicativo. A versão beta passa atualmente por análise estática e testes manuais em navegadores e dispositivos Android.

## Próximos passos

- ampliar a cobertura de testes automatizados;
- criar uma interface administrativa para manutenção controlada dos hinos;
- estudar suporte a várias igrejas com isolamento dos dados;
- concluir a identidade visual e os materiais de publicação.

## Autoria

Concepção, especificação funcional, curadoria dos dados e condução do projeto: **Ronaldo Passarelli**.

Desenvolvimento realizado de forma colaborativa com assistência de inteligência artificial.

## Licenciamento e conteúdo

O licenciamento do código ainda não foi definido. A disponibilização deste repositório para consulta não concede direitos sobre letras de hinos, bases de dados ou futura identidade visual do projeto.
