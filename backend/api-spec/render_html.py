"""Render the offline API reference from the adjacent OpenAPI spec."""

import json
from html import escape
from pathlib import Path
from urllib.parse import urlencode

import yaml


HERE = Path(__file__).resolve().parent
SPEC = yaml.safe_load((HERE / "openapi.yaml").read_text(encoding="utf-8"))
MODELS = SPEC["components"]["schemas"]


def resolve(node):
    while "$ref" in node:
        target = SPEC
        for key in node["$ref"].removeprefix("#/").split("/"):
            target = target[key]
        node = target
    return node


def model_name(node):
    return node.get("$ref", "").split("/")[-1]


def schema_type(schema):
    name = model_name(schema)
    if name:
        return f'<a href="#schema-{escape(name)}">{escape(name)}</a>'
    if "oneOf" in schema:
        return " or ".join(schema_type(option) for option in schema["oneOf"])
    if schema.get("format") == "binary":
        return "binary file"
    kind = schema.get("type", "object")
    if kind == "array":
        return "array of " + schema_type(schema["items"])
    return escape(kind)


def properties(schema):
    schema = resolve(schema)
    required = set(schema.get("required", []))
    fields = dict(schema.get("properties", {}))
    for component in schema.get("allOf", []):
        inherited, needed = properties(component)
        fields.update(inherited)
        required.update(needed)
    return fields, required


def constraints(schema):
    details = resolve(schema)
    parts = []
    if "enum" in details:
        parts.append("Values: " + ", ".join(str(item) for item in details["enum"]))
    if "minimum" in details or "maximum" in details:
        range_text = []
        if "minimum" in details:
            range_text.append(f"min {details['minimum']}")
        if "maximum" in details:
            range_text.append(f"max {details['maximum']}")
        parts.append(", ".join(range_text))
    if details.get("format") == "date":
        parts.append("YYYY-MM-DD")
    if details.get("uniqueItems"):
        parts.append("Unique items")
    if details.get("nullable"):
        parts.append("Allows null")
    return escape(" · ".join(parts))


def example_values(media):
    if "example" in media:
        yield "Example", media["example"]
    for name, linkage in media.get("examples", {}).items():
        example = resolve(linkage)
        yield example.get("summary", name), example["value"]


def code_block(value, content_type):
    text = json.dumps(value, ensure_ascii=False, indent=2) if content_type == "application/json" else str(value).rstrip()
    return f'<pre><code>{escape(text)}</code></pre>'


def paragraph(text):
    return f'<p class="description">{escape(" ".join(text.split()))}</p>' if text else ""


def schema_link(media):
    schema = media.get("schema")
    return f'<div class="schema">Schema {schema_type(schema)}</div>' if schema else ""


def media_example(media, content_type):
    parts = []
    for index, (label, value) in enumerate(example_values(media)):
        if index == 0:
            parts.append(f'<p class="example-label">{escape(label)}</p>{code_block(value, content_type)}')
        else:
            parts.append(f'<details><summary>{escape(label)}</summary>{code_block(value, content_type)}</details>')
    return "".join(parts)


def request_view(path, operation, params):
    url = SPEC["servers"][0]["url"] + path
    query = {}
    rows = []
    for param in params:
        field = param["name"]
        location = param["in"]
        example = param.get("example")
        if location == "path" and example is not None:
            url = url.replace("{" + field + "}", str(example))
        if location == "query" and example is not None:
            query[field] = example
        schema = param["schema"]
        note = escape(param.get("description", ""))
        rows.append(
            f'<tr><th scope="row"><code>{escape(field)}</code></th>'
            f'<td>{escape(location)} · {"required" if param.get("required") else "optional"}</td>'
            f'<td>{schema_type(schema)}<small>{note or constraints(schema)}</small></td>'
            f'<td><code>{escape(str(example)) if example is not None else ""}</code></td></tr>'
        )
    if query:
        url += "?" + urlencode(query)
    parts = [f'<p class="example-label">Example URL</p>{code_block(url, "text/plain")}']
    if rows:
        parts.append('<div class="table-wrap"><table><thead><tr><th>Parameter</th><th>Location</th><th>Type</th>'
                     '<th>Example</th></tr></thead><tbody>' + "".join(rows) + '</tbody></table></div>')
    if not operation.get("requestBody"):
        parts.append('<p class="description">Request body is empty.</p>')
    else:
        body = resolve(operation["requestBody"])
        parts.append(paragraph(body.get("description", "")))
        for content_type, media in body["content"].items():
            parts.append(f'<p class="example-label">Content-Type <code>{escape(content_type)}</code></p>')
            parts.append(schema_link(media))
            parts.append(media_example(media, content_type))
    return "".join(parts)


def response_view(operation):
    parts = []
    for status, link in operation["responses"].items():
        response = resolve(link)
        success = status.startswith("2")
        body = ""
        for header, definition in response.get("headers", {}).items():
            header_text = escape(definition.get("description", ""))
            example = escape(str(definition.get("example", "")))
            body += f'<p class="description">Header <code>{escape(header)}</code> · {header_text} <code>{example}</code></p>'
        for content_type, media in response.get("content", {}).items():
            body += f'<p class="example-label">{escape(content_type)}</p>{schema_link(media)}{media_example(media, content_type)}'
        opened = " open" if success else ""
        color = "success" if success else "error"
        parts.append(
            f'<details class="response"{opened}><summary><code class="status {color}">{escape(status)}</code>'
            f'{escape(response["description"])}</summary><div class="response-body">{body}</div></details>'
        )
    return "".join(parts)


def operations():
    for path, item in SPEC["paths"].items():
        for method, operation in item.items():
            if method not in {"get", "post", "put", "delete", "patch", "head", "options"}:
                continue
            params = [resolve(param) for param in item.get("parameters", []) + operation.get("parameters", [])]
            yield path, method, operation, params


def model_view(name, schema):
    fields, required = properties(schema)
    if not fields:
        return (f'<details class="model" id="schema-{escape(name)}"><summary>{escape(name)}</summary>'
                f'<p>{schema_type(schema)} · {constraints(schema)}</p>{paragraph(schema.get("description", ""))}</details>')
    rows = "".join(
        f'<tr><th scope="row"><code>{escape(field)}</code></th>'
        f'<td>{schema_type(details)}<small>{constraints(details)}</small></td>'
        f'<td>{"Required" if field in required else "Optional"}</td>'
        f'<td>{escape(details.get("description", ""))}</td></tr>'
        for field, details in fields.items()
    )
    return (
        f'<details class="model" id="schema-{escape(name)}"><summary>{escape(name)}</summary>'
        f'{paragraph(schema.get("description", ""))}<div class="table-wrap">'
        '<table><thead><tr><th>Field</th><th>Type</th><th>Presence</th><th>Description</th></tr></thead>'
        f'<tbody>{rows}</tbody></table></div></details>'
    )


def render():
    routes = list(operations())
    navigation = []
    sections = []
    for tag in SPEC["tags"]:
        name = tag["name"]
        navigation.append(f'<h2>{escape(name)}</h2><ul>')
        for path, method, operation, params in routes:
            if operation["tags"][0] != name:
                continue
            path_id = escape(operation["operationId"])
            verb = escape(method.upper())
            badge = f'<span class="method {method}">{verb}</span>'
            navigation.append(f'<li><a href="#{path_id}">{badge}<span>{escape(path)}</span></a></li>')
            sections.append(
                f'<section class="endpoint" id="{path_id}"><h2>{escape(operation["summary"])}</h2>'
                f'<p class="route">{badge}<code>{escape(path)}</code></p>'
                f'{paragraph(operation.get("description", ""))}'
                f'<div class="contract"><div><h3>Request</h3>{request_view(path, operation, params)}</div>'
                f'<div><h3>Responses</h3>{response_view(operation)}</div></div></section>'
            )
        navigation.append("</ul>")
    navigation.append('<p class="model-link"><a href="#models">Data models</a></p>')
    sidebar = "".join(navigation)
    endpoints = "".join(sections)
    models = "".join(model_view(name, schema) for name, schema in MODELS.items())
    title = escape(SPEC["info"]["title"])
    specification = escape(SPEC["openapi"])
    base_url = escape(SPEC["servers"][0]["url"])
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
:root {{
  color-scheme: light;
  --paper: #f9fbfa; --ink: #162720; --muted: #4e635a; --line: #d3ddd7;
  --accent: #176247; --wash: #e9f3ed; --white: #fff;
  --mono: ui-monospace, "SFMono-Regular", Consolas, monospace;
}}
* {{ box-sizing: border-box; }}
html {{ scroll-padding-top: 1.25rem; }}
body {{ margin: 0; color: var(--ink); background: var(--paper); font: 1rem/1.6 system-ui, sans-serif; }}
a {{ color: var(--accent); text-underline-offset: .2em; }}
a:focus-visible, summary:focus-visible {{ outline: 2px solid #177353; outline-offset: 3px; }}
h1, h2, h3, p {{ margin: 0; }}
code {{ font-family: var(--mono); font-size: .88em; }}
.layout {{ display: grid; grid-template-columns: minmax(15rem, 18rem) minmax(0, 1fr); max-width: 100rem; margin: 0 auto; }}
.sidebar {{
  padding: 1.5rem 1rem; border-right: 1px solid var(--line);
  position: sticky; top: 0; align-self: start; max-height: 100vh; overflow: auto;
}}
.brand {{ display: block; font-weight: 750; font-size: 1.1rem; margin-bottom: 1.3rem; text-decoration: none; }}
.sidebar .navigation {{ background: transparent; border: 0; padding: 0; }}
.sidebar .navigation > summary {{ display: none; }}
.sidebar h2 {{ color: var(--muted); font-size: .78rem; margin: 1rem .3rem .3rem; letter-spacing: .025em; }}
.sidebar ul {{ list-style: none; margin: 0; padding: 0; }}
.sidebar li a {{ display: grid; grid-template-columns: 2.65rem minmax(0, 1fr); gap: .38rem; align-items: start; padding: .38rem .3rem; color: var(--ink); text-decoration: none; font: .74rem/1.5 var(--mono); }}
.sidebar li span:last-child {{ overflow-wrap: anywhere; }}
.sidebar li a:hover {{ background: var(--wash); }}
.model-link {{ margin: 1.3rem .3rem; font-size: .9rem; }}
main {{ min-width: 0; padding: clamp(1.1rem, 4vw, 3.1rem); }}
.intro {{ border-top: .27rem solid var(--accent); background: var(--wash); padding: clamp(1.2rem, 4vw, 2.4rem); }}
.intro h1 {{ max-width: 22ch; font-size: clamp(1.9rem, 4vw, 3.25rem); letter-spacing: -.035em; line-height: 1.08; }}
.intro p {{ max-width: 66ch; margin-top: .9rem; color: var(--muted); }}
.intro code {{ color: var(--ink); }}
.spec-link {{ display: inline-block; margin-top: .9rem; font-weight: 650; }}
.quickstart {{ margin: 2rem 0; max-width: 75ch; }}
.quickstart h2 {{ font-size: 1.2rem; }}
.quickstart ol {{ padding-left: 1.4rem; }}
.quickstart li {{ margin-block: .4rem; }}
.endpoint, .models {{ border-top: 1px solid var(--line); padding: 1.8rem 0; }}
.endpoint h2, .models h2 {{ font-size: 1.32rem; line-height: 1.3; letter-spacing: -.015em; }}
.route {{ display: flex; flex-wrap: wrap; gap: .6rem; align-items: center; margin-top: .7rem; overflow-wrap: anywhere; }}
.method, .status {{ font: 700 .73rem/1.4 var(--mono); padding: .16rem .48rem; border-radius: .2rem; display: inline-block; text-align: center; }}
.method.get, .status.success {{ color: #0e543a; background: #dcefe4; }}
.method.post {{ color: #154874; background: #e3eef8; }}
.method.put {{ color: #67441c; background: #f5ead6; }}
.status.error {{ color: #872d25; background: #f6e7e4; }}
.description {{ margin: .6rem 0; color: var(--muted); }}
.contract {{ display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.12fr); gap: 1.2rem; margin-top: 1rem; }}
.contract h3 {{ font-size: .95rem; margin-bottom: .45rem; }}
.example-label, .schema {{ font-size: .79rem; color: var(--muted); margin: .48rem 0 .32rem; }}
pre {{ margin: .35rem 0 .75rem; padding: .85rem; overflow: auto; max-height: 26rem; background: #f0f4f1; border: 1px solid var(--line); border-radius: .25rem; }}
pre code {{ font-size: .78rem; }}
details {{ padding: .52rem .72rem; margin-bottom: .5rem; background: var(--white); border: 1px solid var(--line); border-radius: .25rem; }}
summary {{ cursor: pointer; font-size: .86rem; }}
summary .status {{ margin-right: .5rem; }}
details[open] > summary {{ font-weight: 650; }}
.response-body {{ margin-top: .6rem; min-width: 0; }}
.response-body .description code {{ overflow-wrap: anywhere; }}
.table-wrap {{ overflow-x: auto; margin: .6rem 0; }}
table {{ border-collapse: collapse; width: 100%; font-size: .82rem; }}
th, td {{ text-align: left; vertical-align: top; padding: .4rem .55rem; border-bottom: 1px solid var(--line); }}
thead th {{ background: var(--wash); color: #204735; }}
td small {{ display: block; color: var(--muted); }}
.models h2 {{ margin-bottom: .85rem; }}
.model:target {{ outline: 2px solid var(--accent); }}
@media(max-width: 1050px) {{
  .contract {{ grid-template-columns: minmax(0, 1fr); }}
}}
@media(max-width: 700px) {{
  .layout {{ display: block; }}
  .sidebar {{ position: static; max-height: none; border-right: 0; border-bottom: 1px solid var(--line); }}
  .sidebar .navigation > summary {{ display: list-item; }}
  .brand {{ margin-bottom: .65rem; }}
}}
</style>
<script>
function revealTarget() {{
  const id = location.hash.slice(1);
  const item = document.getElementById(id);
  if (item && item.matches("details")) item.open = true;
}}
addEventListener("hashchange", revealTarget);
addEventListener("DOMContentLoaded", () => {{
  const compact = matchMedia("(max-width: 700px)");
  const navigation = document.querySelector(".navigation");
  const updateNavigation = () => {{ navigation.open = !compact.matches; }};
  compact.addEventListener("change", updateNavigation);
  updateNavigation();
  revealTarget();
}});
</script>
</head>
<body>
<div class="layout">
<nav class="sidebar" aria-label="API endpoints">
  <a class="brand" href="#overview">PromptLearn API</a>
  <details class="navigation" open>
    <summary>Browse endpoints</summary>
    {sidebar}
  </details>
</nav>
<main>
<div class="intro" id="overview">
  <h1>{title}</h1>
  <p>Build and publish a syllabus, review student work with guided questions, or publish lesson recordings for replay.</p>
  <p>Local base URL <code>{base_url}</code></p>
  <a class="spec-link" href="openapi.yaml" download>Download OpenAPI {specification}</a>
</div>
<section class="quickstart" aria-labelledby="workflow">
  <h2 id="workflow">How the endpoints fit together</h2>
  <ol>
    <li>Choose row IDs from <a href="#getMathCurriculum">the curriculum</a> and check class capacity with <a href="#countTeachingPeriods">timetable availability</a>.</li>
    <li>Send the selected rows and period count to <a href="#generateSyllabusDraft">draft generation</a>.</li>
    <li>Edit the plan and use <a href="#previewSyllabus">preview</a> to verify periods, assessment points, and dates.</li>
    <li><a href="#createSyllabus">Save the draft</a>, then <a href="#publishSyllabus">publish it</a>. Students read the latest <a href="#getPublishedSyllabus">published view</a>.</li>
  </ol>
  <p class="description">In an edited plan, assessment period numbers start at 1 within each unit. Responses number periods across the entire semester. HTML strings in examples are shortened.</p>
  <p class="description">For video replay, <a href="#uploadReplayRecording">upload an MP4 for transcription</a>, <a href="#previewReplayRecording">preview the draft as a teacher</a>, then <a href="#publishReplayRecording">publish it</a> for <a href="#getPublishedReplay">student replay</a>. <a href="video-replay-curl.md">Try the flow with curl</a>.</p>
</section>
<section class="quickstart" aria-labelledby="assignment-workflow">
  <h2 id="assignment-workflow">Check assignment work</h2>
  <p>Send the assignment and item IDs, OCR blocks, and paper photo to <a href="#reviewAssignmentWork">assignment review</a>.
     Draw each returned highlight from its original OCR box. Clear highlights for correct or unreadable work.</p>
</section>
{endpoints}
<section class="models" id="models"><h2>Data models</h2>{models}</section>
</main>
</div>
</body>
</html>
"""


if __name__ == "__main__":
    (HERE / "index.html").write_text(render(), encoding="utf-8")
