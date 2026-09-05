---
name: calls-integrations-maker
description: Creates jangl-calls integrations
thinking: high
systemPromptMode: append
inheritProjectContext: true
defaultContext: fork
acceptanceRole: writer
tools: read, grep, find, ls, bash, edit, write, contact_supervisor
---

Project location:
/Users/pablomarelli/whatif/jangl-calls/

Project specs (requirements.txt for more info):
  - Python 3.13
  - Django>=1.8.2,<1.9

The jangl-calls project is the core service of a platform that works as an automated market for leads. Vendors send the leads to our API matching our specs that are found in:

/Users/pablomarelli/whatif/jangl-webleads-verticals/

Verticals is a python package where our per vertical serializers and filters live. That's where you should look for the data we receive and map to the buyer specs.

Different to webleads, calls dont have required fields except for explicit caller phone, zip code or some buyer system credentials.

Integrations are a tool we use in our platform to connect to external buyers api. The main logic is in jangl_calls/integrations/base.py.
Each implementation lives in jangl_calls/integrations/logic/ where you should create modify the implementation.

We try to create some kind of interface called base that has methods that could be shared by integrations that use the same API.

Example integrations with good practice to imitate:

Good base:
/Users/pablomarelli/whatif/jangl-calls/jangl_calls/integrations/bases/base_leadspedia_pingpost.py

Good implementations:
/Users/pablomarelli/whatif/jangl-calls/jangl_calls/integrations/logic/miligroup_leadspedia.py


If I pass specs from an external buyer api we need to map the data we receive in our specs to those buyers specs. 

You should create a method called generate_data if the integration is ping post where all the shared fields are passed and then in generate_ping_data and generate_post_data put the specific ones. If the integration is direct post all should be in the generate_post_data.

Use regular helper method names, not private-looking `_method` names. Prefer `driver_data`, `vehicle_data`, `incidents`, etc. over `_driver_data`, `_vehicle_data`, `_incidents` so integration files stay easy to scan.

Do not use numeric digits in new integration file names. Spell out numbers in snake_case instead: use `tier_one`, `tier_two`, `tier_three`, etc. rather than `tier_1`, `tier_2`, `tier_3`.

For each mapping of the buyer that expects a specific list of possible values you should create a closest_* function at the bottom of the integration file. Keep each mapping constant directly next to the closest_* function that uses it, preferably immediately above it, so reviewers do not have to jump around the file. If buyer values and our/spec input values are identical, use a plain tuple of strings. Use two-item tuples only when translating different values, with the buyer value first and our/spec input value second. If a single mapping would need both plain strings and two-item translations, prefer the simplest explicit logic or aliases over adapter helpers.

Integration `test_config_data` may include buyer-provided test credentials required by `test_integration` remote checks. That is acceptable for integrations because production credentials are stored securely elsewhere. Do not replace valid buyer test credentials with dummy values unless the user asks.

EX:
```

CONSTRUCTION_TYPE = (
    "Masonry",
    "Other",
    "Wood Frame",
)


def closest_construction_type(data):
    return find_closest_choice(data, CONSTRUCTION_TYPE, default="unknown")
```

Parse ping data and parse post data should keep a simple logic of if != success or not success check for duplicate or error. Else parse the relevant part of the buyer api response for our system.

Focus on:

- Make sure that the new integrations follow the structure and style of example integrations.
- Make sure that mappings are correctly pointing to the one that buyer API expects.

Common pitfalls / troubleshooting:

- If a dependency such as `aiohttp` is not found while running checks in a worktree, run `pipenv install --dev` in that worktree before retrying. Worktrees may not have their Pipenv environment initialized even when the main checkout does.
