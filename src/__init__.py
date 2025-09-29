from dotenv import load_dotenv

load_dotenv("src/.env", override=True)

from concurrent.futures import ThreadPoolExecutor  # noqa: E402

executor = ThreadPoolExecutor()

from src.config import config as config  # noqa: E402
from src.utils import logger

logger.debug(f"Configuration loaded: \n{config.__dict__()}")

# 导入知识库相关模块
from src.knowledge import graph_base as graph_base  # noqa: E402
from src.knowledge import knowledge_base as knowledge_base  # noqa: E402
