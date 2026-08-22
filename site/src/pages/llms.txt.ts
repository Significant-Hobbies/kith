import { links, site } from "../site.config";

export const prerender = true;

export function GET() {
  const body = [
    `# ${site.name}`,
    `> ${site.summary}`,
    "",
    "## When to use this",
    "- Best fit: privately tracking the people you want to stay close to on iPhone",
    "- Best fit: logging hangouts, calls, gifts, and small facts that make someone feel known",
    "- Not a fit: social networking, contact management, or CRM-style pipelines",
    "- Not a fit: sharing relationship data or requiring a cloud account to use",
    "",
    "## Primary",
    `- [Product overview](${links.home}index.md): Canonical Markdown summary of ${site.name}.`,
    `- [Privacy](${links.privacy}): Current privacy policy.`,
    `- [Support](${links.support}): Support and feedback.`,
    `- [TestFlight](${links.testflight}): Current beta availability.`,
    "",
    "## Machine surfaces",
    `- [Agent catalog](${site.url}/api/ai)`,
    `- [OpenAPI spec](${site.url}/openapi.json)`,
    `- [Sitemap](${site.url}/sitemap.xml)`,
    `- [This index](${site.url}/llms.txt)`,
    "",
    "## Product boundaries",
    ...site.boundaries.map((item) => `- ${item}`),
    ""
  ].join("\n");
  return new Response(body, { headers: { "content-type": "text/plain; charset=utf-8" } });
}
