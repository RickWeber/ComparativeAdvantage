# Comparative Advantage
# An agent based model of a barter economy with
# N agents producing, exchanging, and consuming
# K goods
#
# Libraries
import numpy as np
from mesa import Model, Agent
from mesa.time import RandomActivation


class mkt(Model):
    def __init__(self, N, K):
        super().__init_()
        self.N = N
        self.K = K
        self.consume = False
        self.trade = True
        self.solo_update = True
        self.money = False  # if True, use good 0 as numeraire
        self.history = []
        self.schedule = RandomActivation(self)
        for a in range(self.N):  # tidy this up
            id = self.next_id()
            id = a
            a = ant(id, self)
            self.schedule.add(a)

    def make_trade(partner1, partner2):
        """
        Trade one turn's production. It's not guaranteed to be mutually
        beneficial, but as agents update their production plans it should
        move in the direction of most trades being beneficial.
        """
        give = partner1.prod * partner1.ppf
        take = partner2.prod * partner2.ppf
        if partner1.has(give) and partner2.has(take):
            partner1.endowment += take
            partner1.endowment -= give
            partner2.endowment -= take
            partner2.endowment += give
        # update production plans
        delta1 = give - take
        partner1.prod_plan += delta1 * partner1.learning_rate
        partner1.prod_plan = partner1.prod_plan / partner1.prod_plan.sum()
        delta2 = take - give
        partner2.prod_plan += delta2 * partner2.learning_rate
        partner2.prod_plan = partner2.prod_plan / partner2.prod_plan.sum()

    def step(self):
        self.schedule.step()
        self.consume = (self.schedule.steps % 5 == 0)


class transfer(exchange):
    def __init__(self, sender, recipient, goods, model):
        super().__init__()
        self.model = model
        self.sender = sender
        self.recipient = recipient
        self.goods = goods

    def undertake(self):
        self.sender.endowment -= self.goods
        self.recipient.endowment += self.goods
        self.model.history.append(self)

class exchange():
    def __init__(self, partners, goods, model):
        self.model = model
        self.partners = partners
        self.goods = goods


class trd():
    def __init__(self, model, **trades):
        self.model = model
        self.partners = trades.keys
        self.items = trades.values != 0
        self.quantities = trades.values

    def evaluate(self):
        return True

    def undertake(self):
        for p in self.partners:
            for i in self.items:
                p.endowment[i] += self.quantities[i]
        # update plans


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
        self.learning_rate = 0.05

    def step(self):
        self.age += 1
        self.produce()
        partner = self.find_partner()
        if self.model.trade:
            self.trade(partner)
        if self.model.consume:
            self.consume()
        if self.model.solo_update:
            self.solo_update()

    def produce(self):
        prod = self.prod * self.ppf
        self.endowment += prod
        return self

    def solo_update(self):
        delta1 = self.u_params * 1/self.u_params.min()
        self.prod_plan += delta1 * self.learning_rate
        self.prod_plan = self.prod_plan / self.prod_plan.sum()

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

    def new_trade(self, partner):
        buyer_gives = np.random.choice(range(self.model.K))
        seller_gives = np.random.choice(range(self.model.K))
        while seller_gives == buyer_gives:
            seller_gives = np.random.choice(range(self.model.K))
        q_sell = min(partner.ppf[seller_gives], partner.endowment[seller_gives])
        q_buy = min(self.ppf[buyer_gives], self.endowment[buyer_gives])
        ratio = q_buy / q_sell
        buyer_tradeoff = self.ppf[seller_gives] / self.ppf[buyer_gives]
        seller_tradeoff = partner.ppf[buyer_gives] / partner.ppf[seller_gives]
        if ratio > buyer_tradeoff or ratio < seller_tradeoff:
            q_sell = 0
            q_buy = 0
        # update endowments
        # update production plans


def easy_model():
    model = mkt(2, 2)
    agent0 = model.schedule.agents[0]
    agent1 = model.schedule.agents[1]
    agent0.u_params = np.array([1/2, 1/2])
    agent1.u_params = np.array([1/2, 1/2])
    agent0.ppf = np.array([4, 1])
    agent1.ppf = np.array([1, 4])
    return model


if __name__ == "__main__":
    mod = easy_model()
