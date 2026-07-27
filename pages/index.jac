"""Root route.

In the standalone calendar app this redirected to `/calendar`, because the
calendar was the whole application. Merged into Neurotech it is not: the
brain UI owns `/` and the calendar is a section under `/calendar`, so this
route mounts the brain client shell that `main.jac` used to render directly.
"""

import from ..frontend { app as ClientApp }


def:pub Home() -> JsxPage {
    return <ClientApp/>;
}
