import numpy as np
from mesa import Model, Agent
from mesa.time import RandomActivation
from mesa.space import MultiGrid
from mesa.datacollection import DataCollector


def utility_reporter(agent):
    """How much utility does agent have right now?"""
    return agent.utility()


def specialization_reporter(agent):
    """How much of agent's time is spent on their most popular good?"""
    return agent.prod_plan.max() / agent.prod_plan.sum()


class ant(Agent):
    """An agent with heterogeneous preferences and capabilities"""
    def __init__(self, unique_id, model, K, N):
        super().__init__(unique_id, model)
        K = self.model.K
        # self.endowment = 10 * np.random.rand(K)
        # self.endowment = np.random.randint(10, 20, K, dtype='float64')
        # self.endowment = self.endowment * 1.0
        # self.endowment.dtype = 'float64'
        self.ppf = np.random.randint(1, 4, K)
        self.endowment = 10. * self.ppf
        prod_plan = np.ones(K)
        self.prod_plan = prod_plan / prod_plan.sum()
        self.prices = self.ppf[0] / self.ppf
        u_params = np.random.randint(1, 4, K)
        self.u_params = u_params / u_params.sum()
        self.trades_done = 0
        self.memory = 10
        self.age = 0
        self.learning_rate = 0.05
        self.specialization = specialization_reporter(self)
        # self.utility = 0

    def step(self):
        self.age += 1
        self.move()
        self.produce()
        if self.model.trade:
            partner = self.find_partner()
            self.trade(partner)
        if self.model.consume:
            self.consume()
        if self.model.solo_update:
            self.solo_update()
        # self.utility = self.utility()
        self.specialization = specialization_reporter(self)

    def move(self):
        possible_steps = self.model.grid.get_neighborhood(
            self.pos,
            moore=True,
            include_center=False)
        new_position = self.random.choice(possible_steps)
        self.model.grid.move_agent(self, new_position)

    def produce(self):
        prod = self.prod_plan * self.ppf
        self.endowment += prod
        return self

    def solo_update(self):
        """Update production plans in the
        direction of what will maximize utility."""
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

    def consume(self, units=5):
        """Use up goods based on weighted probability"""
        # Don't risk going negative
        if self.endowment.max() < 1:
            return self
        if units < 1:
            return self
        probs = self.u_params
        eat = np.random.choice(range(self.model.K),
                               size=1, p=probs)
        self.endowment[eat] -= 1
        self.consume(units - 1)
        return self

    def utility(self):
        return (self.endowment ** self.u_params).sum()

    def trade(self, partner):
        """Create an exchange, """
        # Start with one days production, scale down to match endowments
        deal = exchange([self, partner], self.model)
        deal = deal.day_trade()
        deal.undertake()
        return self

    def has(self, goods):
        have = self.endowment > goods
        return all(have)

    def specialization(self):
        self.prod_plan.max() / self.prod_plan.sum()


class mkt(Model):
    def __init__(self, N, K, width=10, height=10, trade=True):
        super().__init__()
        self.N = N
        self.K = K
        self.consume = False
        self.trade = trade
        self.solo_update = True
        self.money = False
        self.running = True
        self.history = []
        self.grid = MultiGrid(width, height, True)
        self.schedule = RandomActivation(self)
        # create agents
        for a in range(self.N):
            a = ant(a, self)
            self.schedule.add(a)
            x = self.random.randrange(self.grid.width)
            y = self.random.randrange(self.grid.height)
            self.grid.place_agent(a, (x, y))
        all_utility = [agent.utility() for agent in self.schedule.agents]
        self.mean_utility = sum(all_utility) / self.N
        all_spec = [agent.specialization() for agent in self.schedule.agents]
        self.mean_specialization = sum(all_spec) / self.N
        self.datacollector = DataCollector(
            model_reporters={"Mean_Utility": "mean_utility",
                             "Mean_Specialization": "mean_specialization"},
            agent_reporters={"Utility": utility_reporter,
                             "Specialization": specialization_reporter})

    def step(self):
        self.schedule.step()
        self.datacollector.collect(self)
        all_utility = [agent.utility() for agent in self.schedule.agents]
        self.mean_utility = sum(all_utility) / self.N
        all_spec = [agent.specialization() for agent in self.schedule.agents]
        self.mean_specialization = np.mean(all_spec) / self.N


class exchange():
    """A contract between two agents where each partner is giving a
    vector of goods to the other during the current time step."""
    def __init__(self, partners, model, goods=False):
        if not goods:
            goods = [np.zeros(model.K), np.zeros(model.K)]
        self.partners = partners  # Note: this should have two elements
        # Although I could allow n partners as long as each has an associated
        # n-1 vectors for goods.
        self.goods = goods
        self.model = model
        self.delta = self.goods[0] - self.goods[1]

    def undertake(self, update=True):
        p0 = self.partners[0]
        p1 = self.partners[1]
        p0.endowment -= self.goods[0]
        p0.endowment += self.goods[1]
        p1.endowment -= self.goods[1]
        p1.endowment += self.goods[0]
        if update:
            p0.prod_plan += self.delta * p0.learning_rate
            p1.prod_plan -= self.delta * p1.learning_rate
        self.model.history.append(self)

    def day_trade(self):
        part0 = self.partners[0]
        part1 = self.partners[1]
        give = part0.prod_plan * part0.ppf
        take = part1.prod_plan * part1.ppf
        while not (part0.has(give) and part1.has(take)):
            give *= 0.5
            take *= 0.5
        self.goods = [give, take]
        return self

    def hist_trade(self, involving=None):
        history = self.model.history
        if involving:
            keep1 = history["partners"].has(involving)
            history = history[keep1]
        # maybe randomly flip direction?
        goods = np.random.choice(history["goods"])
        self.goods = goods
        return self

    def rand_trade(self):
        goods = [
            np.random.randint(-2, 2, self.model.K),
            np.random.randint(-2, 2, self.model.K)
        ]
        self.goods = goods
        return self
