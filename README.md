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
 1 name:PC_Tst               own:kkk      group:         path:kkk/pc_tst                     desc:-
 2 name:atl_test             own:rrr      group:         path:rrr/atl-test                   desc:-
 3 name:Calc                 own:lav      group:Gam      path:gam/gam-calc                   desc:The calc calibration

 0: import kkk/pc_tst   ... OK
 1: import rrr/atl-test ... OK
...
```

