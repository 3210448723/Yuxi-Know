from dotenv import load_dotenv

load_dotenv("src/.env", override=True)

from concurrent.futures import ThreadPoolExecutor  # noqa: E402

executor = ThreadPoolExecutor()

from src.config import config as config  # noqa: E402
from src.utils import logger

logger.debug(f"Configuration loaded: \n{config.__dict__()}")

# 导入知识库相关模块
from src.knowledge.chroma_kb import ChromaKB  # noqa: E402
from src.knowledge.kb_factory import KnowledgeBaseFactory  # noqa: E402
from src.knowledge.kb_manager import KnowledgeBaseManager  # noqa: E402
from src.knowledge.lightrag_kb import LightRagKB  # noqa: E402
from src.knowledge.milvus_kb import MilvusKB  # noqa: E402
from src.knowledge import graph_base as graph_base  # noqa: E402
from src.knowledge import knowledge_base as knowledge_base  # noqa: E402

# 注册知识库类型
KnowledgeBaseFactory.register("chroma", ChromaKB, {"description": "基于 ChromaDB 的轻量级向量知识库，适合开发和小规模"})
KnowledgeBaseFactory.register("milvus", MilvusKB, {"description": "基于 Milvus 的生产级向量知识库，适合高性能部署"})
KnowledgeBaseFactory.register("lightrag", LightRagKB, {"description": "基于图检索的知识库，支持实体关系构建和复杂查询"})
