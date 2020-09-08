# Libraries
import pandas as pd
from mesa import Model
from mesa.time import RandomActivation
from mesa.datacollection import DataCollector
from agents import BarterAgent
from model import utility_reporter
from model import specialization_reporter


class Market(Model):
    """
    An economy with N agents and K goods
    """
    def __init__(self, N, K):
        super().__init__()
        self.N = N
        self.K = K
        self.schedule = RandomActivation(self)
        self.history = pd.DataFrame({
            "initiator": [],
            "partner": [],
            "deal": [],
            "trades": []
        })
        self.trades_undertaken = 0
        self.possible_trades = self.generate_possible_trades(K)
        # create agents
        for i in range(N):
            a = BarterAgent(self.next_id(), self)
            self.schedule.add(a)
        # collect data
        self.datacollector = DataCollector(
            model_reporters={"Number of trades": "self.trades_undertaken"},
            agent_reporters={"Utility": utility_reporter,
                             "Specialization": specialization_reporter}
        )

    def step(self):
        self.datacollector.collect(self)
        self.schedule.step()

    def generate_possible_trades(self, K):
        poss_trades = [(x, y) for x in range(K) for y in range(K) if x != y]
        poss_trades = pd.DataFrame(poss_trades)
        poss_trades.rename(columns={'0': 'buy', '1': 'sell'}, inplace=True)
        return poss_trades
