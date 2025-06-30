bundle add glancer --path=...
rails generate glancer:install
rails db:migrate

HuggingFaceEmbeddings(model_name="local_models/all-MiniLM-L6-v2") - (python)

embedings for localmodels? 
quota? 1 per question (ideal world)
different models for embeddings and completions?
  config.llm_provider = :gemini      
  config.embedding_provider = :ollama
