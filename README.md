# gitlab-to-gitea-script
Migrate remote gitlab repository to gitea


### Note

The Gitlab groups is migrating to $GITEA_USERNAME.

### Example of using

```
$ ./gitlab-to-gitea.sh
*** check connection          ... OK
*** check group               ... OK
 1: Gam
 2: Sar
 3: Other
 4: Enc
*** get repo list
    get id                    ... OK
    get name                  ... OK
    get description           ... OK
    get owner                 ... OK
    get group                 ... OK
    get path                  ... OK
    get webpath               ... OK

*** found repo:
 1 name:PCDR_Tst             own:kav      group:         path:kav/pcdr_tst                   desc:-
 2 name:atl_test             own:rvv      group:         path:rvv/atlas-test                 desc:-
 3 name:Calibration          own:lav      group:Gam      path:gam/gam-calibration            desc:The zond calibration

 0: import kav/pcdr_tst ... OK
 1: import rvv/atl-test ... OK
...
```

