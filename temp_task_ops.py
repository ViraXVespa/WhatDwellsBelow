import sys
from pathlib import Path
from tools.lib.skills_wrappers import task_ops
prompt = "Generate Grok Build tasks from the contents of the file at C:\\Users\\Vira\\Desktop\\tasks.md. Provide task definitions ready to commit to design/tasks/. The file contains two tasks. Please output the tasks in the correct format."
print(task_ops(prompt))