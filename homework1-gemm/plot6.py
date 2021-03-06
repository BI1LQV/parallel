import csv
import matplotlib.pyplot as plt

#TYPE = 'gflops'
TYPE = 'time'
kmn = csv.reader(open('./switch/kmn'), delimiter=',', quotechar='|')
knm = csv.reader(open('./switch/knm'), delimiter=',', quotechar='|')
mkn = csv.reader(open('./switch/mkn'), delimiter=',', quotechar='|')
mnk = csv.reader(open('./switch/mnk'), delimiter=',', quotechar='|')
nkm = csv.reader(open('./switch/nkm'), delimiter=',', quotechar='|')
nmk = csv.reader(open('./switch/nmk'), delimiter=',', quotechar='|')

x = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100,
     1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000]
yt = []
ygflops = []


def gety(name):
    ygflops = []
    yt = []

    for row in name:
        if len(row):
            ygflops.append(float(row[2]))
            yt.append(float(row[1]))
    return [ygflops, yt]


fig, ax = plt.subplots()
# if TYPE == 'gflops':
#     y = ygflops
# else:
#     y = yt

ax.plot(x, gety(kmn)[1], linewidth=2.0,label="kmn",marker="o")
ax.plot(x, gety(knm)[1], linewidth=2.0,label="knm",marker=".")
ax.plot(x, gety(mkn)[1], linewidth=2.0,label="mkn",marker="*")
ax.plot(x, gety(mnk)[1], linewidth=2.0,label="mnk",marker="+")
ax.plot(x, gety(nkm)[1], linewidth=2.0,label="nkm",marker="v")
ax.plot(x, gety(nmk)[1], linewidth=2.0,label="nmk",marker="H")
plt.legend()
plt.xlabel('square matrix size')
if TYPE == 'gflops':
    plt.ylabel('GFLOPS')
else:
    plt.ylabel('time (s)')
ax.set(xlim=(0, 2100), ylim=(0, 110*1.1))
plt.xticks(list(range(0, max(x)+100, 200)),
           [str(i) for i in range(0, max(x)+100, 200)])
plt.savefig('./figs/'+'6'+TYPE+'.png')
