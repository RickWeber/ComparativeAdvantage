# Comparative Advantage
# An agent based model of a barter economy with
# N agents producing, exchanging, and consuming
# K goods
#
# Libraries
import numpy as np
import pandas as pd
from mesa import Model
from mesa import Agent
from mesa.time import RandomActivation
import copy


# Here's a dumb idea: I'm going to just rebuild my classes with new names...
class mkt(Model):
    def __init__(self, N, K):
        super().__init_()
        self.N = N
        self.K = K
        self.consume = False
        self.trade = True
        self.schedule = RandomActivation(self)

    def make_trade(partner1, partner2):
        """Decide the terms,
        verify that it's beneficial,
        then update appropriately"""
        give = partner1.prod * partner1.ppf
        take = partner2.prod * partner2.ppf
        if partner1.has(give) and partner2.has(take):
            partner1.endowment += take
            partner1.endowment -= give
            partner2.endowment -= take
            partner2.endowment += give
        # update production plans
        learning_rate = 0.05
        delta1 = give - take
        partner1.prod_plan += delta1 * learning_rate
        partner1.prod_plan = partner1.prod_plan / partner1.prod_plan.sum()
        delta2 = take - give
        partner2.prod_plan += delta2 * learning_rate
        partner2.prod_plan = partner2.prod_plan / partner2.prod_plan.sum()

    def step(self):
        self.schedule.step()
        self.consume = (self.schedule.steps % 5 == 0)


class ant(Agent):
    def __init__(self, unique_id, model):
        super().__init__(unique_id, model)
        self.endowment = np.random.randint(10, 20, model.K)
        self.ppf = np.random.randint(1, 4, model.K)
        prod_plan = np.ones(model.K)
        self.prod_plan = prod_plan / prod_plan.sum()
        self.prices = self.ppf[0] / self.ppf  # good 0 as numeraire
        u_params = np.random.randint(1, 4, model.K)
        self.u_params = u_params / u_params.sum()
        self.trades_undertaken = 0
        self.cumulative_utility = 0
        self.memory = 10
        self.age = 0

    def step(self):
        self.age += 1
        self.produce()
        partner = self.find_partner()
        if self.model.trade:
            self.trade(partner)
        if self.model.consume:
            self.consume()

    def produce(self):
        prod = self.prod * self.ppf
        self.endowment += prod
        return self

    def find_partner(self):
        p = np.random.randint(self.model.schedule.get_agent_count())
        if p > 1:
            partner = self.model.schedule.agents[p]
            if partner == self:
                partner = self.find_partner()
            return partner
        else:
            return self

    def trade(self, partner):
        self.model.make_trade(self, partner)
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

    def utility(self):
        return (self.endowment ** self.u_params).sum()


class Market(Model):
    def __init__(self, N, K):
        super().__init__()
        self.N = N
        self.K = K
        self.possible_trades = self.gen_pos_trades(K)
        self.schedule = RandomActivation(self)
        self.history = pd.DataFrame({
            "partner1": [],
            "partner2": [],
            "deal": [],
            "trades": []
        })
        self.trades_undertaken = 0
        # create agents
        for i in range(N):
            a = BarterAgent(self.next_id(), self)
            self.schedule.add(a)

    def step(self):
        self.schedule.step()

    def gen_pos_trades(self, K):
        poss_trades = [(x, y) for x in range(K) for y in range(K) if x != y]
        poss_trades = pd.DataFrame(poss_trades)
        poss_trades.rename(columns={0: 'buy', 1: 'sell'}, inplace=True)
        return poss_trades

    def gen_numeraire_trades(self, K):
        """
        Allow a version of the model where all trades involve "cash"
        by designating good 0 as a numeraire.
        """
        poss_trades = [(x, y) for x in range(K) for y in range(K)
                       if (x != y and (x == 0 or y == 0))]
        poss_trades = pd.DataFrame(poss_trades)
        poss_trades.rename(columns={0: 'buy', 1: 'sell'}, inplace=True)
        return poss_trades


class BarterAgent(Agent):
    """
    An agent with preferences and capabilities
    that produces and trades to enhance utility.
    """
    def __init__(self, unique_id, model):
        super().__init__(unique_id, model)
        self.production = np.ones(model.K)
        self.trades = np.ones(model.possible_trades.shape[0])
        self.ppf = np.random.randint(1, 4, model.K)
        # maximum prices are defined by the slope of the ppf
        self.prices = np.array(
            [self.ppf[y]/self.ppf[x]
             for x in range(model.K)
             for y in range(model.K)
             if x != y]
        )
        p = model.possible_trades.shape[0]
        self.prices = np.array(shape=p)
        for i in p:
            buy = model.possible_trades[i, 0]
            sell = model.possible_trades[i, 1]
            price = sell/buy
            self.prices.iloc[i] = price
        self.endowment = np.random.randint(10, 20, model.K)
        u_params = np.random.randint(1, 4, model.K)
        self.u_params = u_params / u_params.sum()
        self.trades_undertaken = 0
        self.cumulative_utility = 0
        self.memory = 10
        self.age = 0

    def history(self):
        full_history = self.model.history
        my_buys = full_history["partner1"] == self
        my_sells = full_history["partner2"] == self
        return full_history[my_buys or my_sells]

    def step(self):
        self.age += 1
        self.produce()
        partner = self.find_partner()
        self.trade(partner)
        self.consume()

    def produce(self, factor=1):
        plan = self.production / self.production.sum()
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

    ### Work on stuff below ###
    def trade(self, partner, complexity=1):
        prob = self.trades / self.trades.sum()
        index = np.random.choice(self.model.possible_trades.index,
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
                "partner1": [self],
                "partner2": [partner],
                "deal": [deal],
                "trades": [trades]
            })
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
        mutation = self.random_mutation()
        doppelganger = copy.deepcopy(self).mutate(mutation)
        if doppelganger.produce().utility() > baseline:
            self.mutate(mutation)
        return self

    def update(self):
        """Produce more of what I have comparative
        advantage in... Or, if I can't trade, whatever
        gives me greater expected utility."""
        history = self.model.history["partner1" == self | "partner2" == self]
        history = history.tail(self.memory)
        last_deal = history.tail(1)
        if last_deal["partner1"] == self:
            self.endowment += last_deal["deal"]
        else:
            self.endowment -= last_deal["deal"]
        self.trades_undertaken += 1
        # self.prod_plan[last_deal["deal"]] += 1
        # update prod_plan to make more of something I sold
        choice = np.random.choice(last_deal["trades"], 1)
        make_more_of = choice[1]
        self.mutate("production", make_more_of, 1)
        self.mutate("trades", last_deal["trades"], 1)
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

    def reproduce(self, **mutations):
        baby = copy.deepcopy(self)
        baby.trades_done = 0
        baby.cumulative_utility = 0
        baby.age = 0
        if mutations:
            baby = baby.mutate(mutations)
        # add to schedule
        self.model.schedule.add(baby)
        return baby

    # rebuild to work with lines 174/175
    def mutate(self, **mutations):
        for key, value in mutations:
            if key == "production":
                self.production += value
            if key == "trades":
                self.trades += value
            if key == "u_params":
                self.u_params += value
                self.u_params = self.u_params / self.u_params.sum()
            if key == "ppf":
                self.ppf += value
                self.prices = [self.ppf[y]/self.ppf[x]
                               for (x, y)
                               in self.model.possible_trades]
            if key == "endowment":
                self.endowment += value
        return self

    def random_mutation(self):
        options = ["production", "trades", "u_params", "ppf", "endowment"]
        prob = np.array([10, 10, 2, 2, 1])
        prob = prob / prob.sum()
        key = np.random.choice(options, 1, p=prob)
        value = 1
        return {key: value}


def utility_reporter(agent):
    """How much utility does agent have right now?"""
    return agent.utility()


def specialization_reporter(agent):
    """How much of agent's time is spent on their most popular good?"""
    return agent.prod_plan.max() / agent.prod_plan.sum()


def compare(vect, basis):
    """Compare a vector to some basis. Used to map a deal and an agent's ppf
    to a real number. If that number is positive, it means they come out ahead
    on the deal relative to no ability to trade."""
    out = vect * (basis[0] / basis)
    return out.sum()  # check this.


def easy_model():
    model = Market(2, 2)
    agent0 = model.schedule.agents[0]
    agent1 = model.schedule.agents[1]
    agent0.u_params = np.array([1/2, 1/2])
    agent1.u_params = np.array([1/2, 1/2])
    agent0.ppf = np.array([4, 1])
    agent1.ppf = np.array([1, 4])
    return model
