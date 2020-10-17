from mesa.visualization.ModularVisualization import ModularServer
from mesa.visualization.modules import TextElement
from mesa.visualization.UserParam import UserSettableParameter
from market import Market


class utility_element(TextElement):
    def __init__(self):
        pass

    def render(self, model):
        return "Mean utility: " + str(model.Utility.mean())


model_params = {
    "N": UserSettableParameter("slider", "N", 2, 2, 10, 1),
    "K": UserSettableParameter("slider", "K", 2, 2, 10, 1),
}

server = ModularServer(
    model_cls=Market,
    visualization_elements=[utility_element],
    name="Comparative Advantage",
    model_params=model_params
)
