bundle add glancer --path=...
rails generate glancer:install
rails db:migrate



HuggingFaceEmbeddings(model_name="local_models/all-MiniLM-L6-v2") - (python)

embedings for localmodels? 
quota? 1 per question (ideal world)
different models for embeddings and completions?
  config.llm_provider = :gemini      
  config.embedding_provider = :ollama




- não passar os dados para o LLM, passar a consulta para ele e ele vai tentar explicar de forma humanizada como pensou para buscar os dados.
- Sempre mostra uma tabela com o raw_data
- tenta formatar para gerar gráficos ou algo interessante
- gerar blobs, dados possíveis de serem baixados
- tool para ordenar os dados?
- poder conversar com um llm sobre os dados de uma mensagem?
- criar dashboard de monitoramento?
- compartilhar query?

