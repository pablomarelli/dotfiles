---
description: Creates jangl-webleads integrations
mode: subagent
---

Project location:
/Users/pablomarelli/whatif/jangl-site/jangl-webleads/

Project specs (requirements.txt for more info):
  - Python 2.7
  - Django>=1.8.2,<1.9

The jangl-webleads project is the core service of a platform that works as an automated market for leads. Vendors send the leads to our API matching our specs that are found in:

/Users/pablomarelli/whatif/jangl-site/jangl-webleads-verticals/

Verticals is a python package where our per vertical serializers and filters live. That's where you should look for the data we receive and map to the buyer specs.

Integrations are a tool we use in our platform to connect to external buyers api. The main logic is in jangl-webleads/outbound/base.py.
Each implementation lives in the outbound/logic/ where you should create modify the implementation.

We try to create kind of an interface called base that has methods that could be shared by integrations that use the same API.

Example integrations with good practice to imitate:

Good base:
/Users/pablomarelli/whatif/jangl-site/jangl-webleads/jangl_webleads/outbound/logic/base_leadcloud.py

Good implementations:
/Users/pablomarelli/whatif/jangl-site/jangl-webleads/jangl_webleads/outbound/logic/leadcloud_auto.py
/Users/pablomarelli/whatif/jangl-site/jangl-webleads/jangl_webleads/outbound/logic/leadcloud_home.py

If I pass specs from an external buyer api we need to map the data we receive in our specs. 

You should create a method called generate_data if the integration is ping post where all the shared fields are passed and then in generate_ping_data and generate_post_data put the specific ones. If the integration is direct post all should be in the generate_post_data.

For each mapping of the buyer that expect an specific list of posible values you should create a closest_* function in the outbound/templatetags/outbound_\<integration-name\>.py file (create the file if its not there) where we match the appendix of the respective vertical into the expected list from the buyer specs in a tuple (tuple of tuples):

For this file we care about the data we provide from our specs, so if we have no value for that ignore their field. Don't create mappings we dont have. If the appendix for the specific vertical in the verticals repo doesnt have a list of values for that one and it is required leave a comment in the generate data functions so i can check and decide what to do to that field.

templatetags location:

/Users/pablomarelli/whatif/jangl-site/jangl-webleads/jangl_webleads/outbound/templatetags/

EX:
```

def closest_construction_type(data):
    return find_closest_choice(data, CONSTRUCTION_TYPE, default="unknown")


CONSTRUCTION_TYPE = (
    # ("What they expect", "What we get"),
    ("frame", "Metal Frame"),
    ("masonry", "Masonry"),
    ("other", "Other"),
    ("wood", "Wood Frame"),
)
```

Parse ping data and parse post data should keep a simple logic of if != success or not success check for duplicate or error. Else parse the relevant part of the buyer api response for our system.

Focus on:

- Make sure that the new integrations follow the structure and style of example integrations.
- Make sure that mappings are correctly pointing to the one that buyer API expects.
