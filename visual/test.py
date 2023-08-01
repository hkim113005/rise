import numpy as np
import matplotlib.pyplot as plt
import matplotlib.cm as cm

tstop = 276000
dt = 0.01

f = open("../data", "r")
r = f.read().strip().split("\n")
n_r = [a.split("\t ") for a in r]
n_r = [[eval(a) / 1000, eval(b)] for a, b in n_r]

x = [[] for i in range(100)]
for n in n_r:
    x[n[-1]].append(n[0])

# print(x[0])

#for y in x:
    #print(len(y))

#print(len(x))

"""
g = open("../output/LAd[34]_LAd[17]_Ca")
ca = [eval(a) for a in g.read().strip().split("\n")]
print(n_r)

# t_vector = np.arange(0, 690.01, dt)

plt.eventplot(n_r)     
plt.show()
"""

NUM_COLORS = len(x)

cm = plt.get_cmap('gist_rainbow')
colors = []
for i in range(NUM_COLORS):
    colors.append(cm(1. * i / NUM_COLORS))

line_sizes = [1.0 for i in range(len(x))]

plt.eventplot(x, color=colors, linelengths=line_sizes)     

plt.xlabel("Spike")
plt.ylabel("Neuron")

plt.show()