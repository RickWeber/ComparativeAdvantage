# Libraries
import numpy as np
import pandas as pd
from mesa import Agent
import copy
from model import compare


class BarterAgent(Agent):
    """
    An agent with preferences and capabilities
    that produces and trades to enhance utility.
    """
    def __init__(self, unique_id, model):
        super().__init__(unique_id, model)
        self.plans = {
            "production": np.ones(model.K),
            "trades": np.ones(model.possible_trades)
        }
        self.ppf = np.random.randint(1, 4, model.K)
        # maximum prices are defined by the slope of the ppf
        prices = [self.ppf[y]/self.ppf[x] for (x, y) in model.possible_trades]
        self.prices = prices
        self.endowment = np.random.randint(10, 20, model.K)
        u_params = np.random.randint(1, 4, model.K)
        self.u_params = u_params / u_params.sum()
        self.history = pd.DataFrame({
            "initiator": [],
            "partner": [],
            "deal": [],
            "trades": []
        })
        self.trades_done = 0
        self.cumulative_utility = 0

    def step(self):
        self.produce()
        self.trade(self.find_partner())
        self.consume()

    def produce(self, factor=1):
        plan = self.plan["production"] / self.plan["production"].sum()
        prod = plan * self.ppf
        prod = plan * factor
        prod = int(prod)
        self.endowment += prod
        return self

    def consume(self, units=5):
        """Use up goods based on weighted probability"""
        # Don't risk going negative
        if self.endowment.min() < units:
            return self
        probs = self.u_params
        eat = np.random.choice(range(self.model.K),
                               size=units,
                               replace=True, p=probs)
        for e in eat:
            self.endowment[e] -= 1
            # this is sort of a goofy way to track utility. I'll fix it later
            self.cumulative_utility += self.u_params[e]
        return self

    def trade(self, partner, complexity=1):
        prob = self.plans["trades"] / self.plans["trades"].sum()
        index = np.random.randint(range(self.model.possible_trades.size[0]),
                                  size=complexity,
                                  replace=True,
                                  p=prob)
        trades = self.model.possible_trades.loc[index]
        prices = [(1, np.random.randint(1, self.prices[i])) for i in index]
        prices = np.array(prices)
        deal = self.vectorize_deal(trades, prices)
        # But this is also a place for a price expectation vector...
        # Currently just comparing the deal to agents' ppfs
        # But we could allow more elaborate behavior:
        # * Check self.model.history.filter(contains(trades))
        # * Create and learn some price expectation vector
        good_for_goose = compare(deal, self.ppf) > 0
        good_for_gander = compare(-deal, partner.ppf) > 0
        if not good_for_goose or not good_for_gander:
            self.solo_update()
            return self
        else:
            hist_update = pd.DataFrame({
                "initiator": [self],
                "partner": [partner],
                "deal": [deal],
                "trades": [trades]
            })
            self.history = pd.concat([self.history, hist_update])
            partner.history = pd.concat([partner.history, hist_update])
            self.model.history = pd.concat([self.model.history, hist_update])
            self.update()
            partner.update()
        return self

    def find_partner(self):
        p = np.random.randint(self.model.schedule.get_agent_count())
        partner = self.model.schedule.agents[p]
        if partner == self:
            partner = self.find_partner()
        return partner

    def solo_update(self):
        """update production plans"""
        baseline = self.produce().utility()
        self.produce(-1)
        doppelganger = copy.deepcopy(self)
        mutation = np.random.randint(self.model.K)
        doppelganger.plans["production"].loc[mutation] += 1
        if doppelganger.produce().utility() > baseline:
            self.plans["production"].loc[mutation] += 1
        return self

    def update(self):
        """Produce more of what I have comparative
        advantage in... Or, if I can't trade, whatever
        gives me greater expected utility."""
        last_deal = self.history.tail(1)
        if last_deal["initiator"] == self:
            self.endowment += last_deal["deal"]
        else:
            self.endowment -= last_deal["deal"]
        self.trades_undertaken += 1
        # self.prod_plan[last_deal["deal"]] += 1
        # update prod_plan to make more of something I sold
        make_more_of = last_deal["trades"][1][1]
        self.plans["production"].loc[make_more_of] += 1
        self.trade_plan.loc[self.trade_plan == last_deal["trades"]] += 1
        return self

    def utility(self):
        """Calculate utility based on endowment and Cobb-Douglas preferences"""
        (self.endowment ** self.u_params).sum()

    def vectorize_deal(self, trades, quantities):
        deal = np.zeros(self.model.K)
        for (t1, t2), (p1, p2) in trades, quantities:
            deal[t1] += p1
            deal[t2] -= p2
        return deal

    def reproduce(self, mutation=False):
        baby = copy.deepcopy(self)
        if mutation:
            change = np.random.randint(self.model.K)
            baby.plans["production"].loc[change] += 1
        return baby
