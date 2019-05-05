Benchmarked using https://github.com/gamache/httpc_bench

10ms requests
clients running on m5.4xlarge (16 vCPUs, 64 GB RAM)
server running on m5.metal (96 vCPUs, 384 GB RAM)

```
Client     PoolCount  PoolSize  Concurrency  Requests/s  Error %

Mojito            16       512        16384       35737      2.7
Mojito             4       512        16384       35060      2.4
Mojito             1       512        16384       31318      5.0
Buoy               1       512        16384       35131     89.6
Dlhttpc            1       512        16384       12227     98.0
Hackney            1       512        16384       12914      0.0
Mojito            16       256        16384       20854      2.3
Mojito             4       256        16384       20673      2.4
Mojito             1       256        16384       19540      4.2
Buoy               1       256        16384       18359     94.8
Dlhttpc            1       256        16384        3959     98.9
Hackney            1       256        16384       17938      0.0
Mojito            16       128        16384       18012     25.4
Mojito             4       128        16384       17202     24.2
Mojito             1       128        16384        9490     47.3
Buoy               1       128        16384        8791     97.6
Dlhttpc            1       128        16384        3499     99.5
Hackney            1       128        16384       10598      0.0

Mojito            16       512         8192       38587      1.0
Mojito             4       512         8192       38841      1.0
Mojito             1       512         8192       36915      1.1
Buoy               1       512         8192       37010     89.8
Dlhttpc            1       512         8192        8944     97.2
Hackney            1       512         8192       14627      0.0
Mojito            16       256         8192       21708      1.1
Mojito             4       256         8192       21721      1.1
Mojito             1       256         8192       21190      1.1
Buoy               1       256         8192       18859     94.9
Dlhttpc            1       256         8192        8535     98.7
Hackney            1       256         8192       19457      0.0
Mojito            16       128         8192       11358      1.4
Mojito             4       128         8192       11357      1.4
Mojito             1       128         8192       11216      1.3
Buoy               1       128         8192        9617     97.4
Dlhttpc            1       128         8192        4236     99.4
Hackney            1       128         8192       11178      0.0

Mojito            16       512         4096       42205      0.9
Mojito             4       512         4096       39519      1.1
Mojito             1       512         4096       42355      0.9
Buoy               1       512         4096       34579     89.8
Dlhttpc            1       512         4096       10904     95.3
Hackney            1       512         4096       15923      0.0
Mojito            16       256         4096       22436      1.0
Mojito             4       256         4096       22460      1.0
Mojito             1       256         4096       22472      1.0
Buoy               1       256         4096       19005     94.9
Dlhttpc            1       256         4096        9647     98.4
Hackney            1       256         4096       20945      0.0
Mojito            16       128         4096       11521      1.0
Mojito             4       128         4096       11513      1.0
Mojito             1       128         4096       11515      1.0
Buoy               1       128         4096        9646     97.5
Dlhttpc            1       128         4096        5282     99.2
Hackney            1       128         4096       11389      0.0

Mojito            16       512         2048       42338      0.9
Mojito             4       512         2048       36611      1.3
Mojito             1       512         2048       37827      1.2
Buoy               1       512         2048       30955     89.8
Dlhttpc            1       512         2048       10697     92.7
Hackney            1       512         2048       17491      0.0
Mojito            16       256         2048       22262      1.0
Mojito             4       256         2048       22827      1.0
Mojito             1       256         2048       21251      1.1
Buoy               1       256         2048       17157     94.9
Dlhttpc            1       256         2048        3155     97.7
Hackney            1       256         2048       21750      0.0
Mojito            16       128         2048       11563      1.0
Mojito             4       128         2048       11559      1.0
Mojito             1       128         2048       11566      1.0
Buoy               1       128         2048        9061     97.4
Dlhttpc            1       128         2048        5546     99.0
Hackney            1       128         2048       11439      0.0

Mojito            16       512         1024       32506      2.0
Mojito             4       512         1024       33232      1.8
Mojito             1       512         1024       35554      1.6
Buoy               1       512         1024       16372     70.9
Dlhttpc            1       512         1024       12927     85.1
Hackney            1       512         1024       19103      0.0
Mojito            16       256         1024       22802      1.0
Mojito             4       256         1024       22850      1.0
Mojito             1       256         1024       21994      1.0
Buoy               1       256         1024        8120     92.1
Dlhttpc            1       256         1024        4019     95.2
Hackney            1       256         1024       22366      0.0
Mojito            16       128         1024       11582      1.0
Mojito             4       128         1024       11573      1.0
Mojito             1       128         1024       11570      1.0
Buoy               1       128         1024        8535     97.4
Dlhttpc            1       128         1024        4900     98.6
Hackney            1       128         1024       11469      0.0

Mojito            16       512          512       30411      1.9
Mojito             4       512          512       30169      2.1
Mojito             1       512          512       27952      2.1
Buoy               1       512          512       19900     37.0
Dlhttpc            1       512          512       17722     72.2
Hackney            1       512          512       17181      0.0
Mojito            16       256          512       22730      1.0
Mojito             4       256          512       18661      1.7
Mojito             1       256          512       18579      2.3
Buoy               1       256          512       10878     58.1
Dlhttpc            1       256          512        3618     92.1
Hackney            1       256          512       22009      0.0
Mojito            16       128          512       11569      1.0
Mojito             4       128          512       10111      2.0
Mojito             1       128          512       11563      1.0
Buoy               1       128          512        4115     94.4
Dlhttpc            1       128          512        4266     98.0
Hackney            1       128          512       11472      0.0
```
