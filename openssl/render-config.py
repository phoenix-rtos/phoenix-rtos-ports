import jinja2
import os
import sys
from pathlib import Path

tmpl = Path(sys.argv[1]).read_text()
rendered = jinja2.Template(tmpl, undefined=jinja2.StrictUndefined).render(env=os.environ)

print(rendered)
