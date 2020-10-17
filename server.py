from mesa.visualization.modules import CanvasGrid, ChartModule, TextElement
from mesa.visualization.ModularVisualization import ModularServer
from mesa.visualization.UserParam import UserSettableParameter
from model import mkt


class UtilityElement(TextElement):
    """Display the average utility of agents in the model."""
    def __init__(self):
        pass

    def render(self, model):
        return "Mean utility: " + str(model.mean_utility)


def agent_portrayal(agent):
    portrayal = {"Shape": "circle",
                 "Filled": "true",
                 "r": 0.5,
                 "Color": "red",
                 "Layer": 0}
    return portrayal


model_params = {
    "N": UserSettableParameter("slider",
                               "Number of agents",
                               value=50,
                               min_value=2,
                               max_value=100,
                               step=1),
    "K": UserSettableParameter("slider",
                               "Number of goods",
                               value=2,
                               min_value=2,
                               max_value=10,
                               step=1),
    "width": 10,
    "height": 10,
    "trade": UserSettableParameter("choice",
                                   "Allow trade?",
                                   value=True,
                                   choices=[True, False])
}

utility_element = UtilityElement()
grid = CanvasGrid(agent_portrayal, 10, 10, 500, 500)
utility_chart = ChartModule([{"Label": "Mean_Utility",
                              "Color": "Black"}],
                            data_collector_name='datacollector')
specialization_chart = ChartModule([{"Label": "Mean_Specialization",
                                     "Color": "Green"}],
                                   data_collector_name='datacollector')
server = ModularServer(mkt,
                       [grid,
                        utility_chart,
                        specialization_chart,
                        utility_element],
                       "Money Model",
                       model_params)
