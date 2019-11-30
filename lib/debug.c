#include <config.h>

#include "netdev-linux.h"
#include "netdev-linux-private.h"

#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <inttypes.h>
#include <math.h>
#include <linux/filter.h>
#include <linux/gen_stats.h>
#include <linux/if_ether.h>
#include <linux/if_tun.h>
#include <linux/types.h>
#include <linux/ethtool.h>
#include <linux/mii.h>
#include <linux/rtnetlink.h>

char* rtm_to_string(int code)
{
  char *rtm_name;

  switch(code)
  {
  case RTM_NEWLINK:
    rtm_name = "RTM_NEWLINK";
    break;

  case RTM_DELLINK:
    rtm_name = "RTM_DELLINK";
    break;

  case RTM_GETLINK:
    rtm_name = "RTM_GETLINK";
    break;

  case RTM_SETLINK:
    rtm_name = "RTM_SETLINK";
    break;

  case RTM_NEWADDR:
    rtm_name = "RTM_NEWADDR";
    break;

  case RTM_DELADDR:
    rtm_name = "RTM_DELADDR";
    break;

  case RTM_GETADDR:
    rtm_name = "RTM_GETADDR";
    break;

  case RTM_NEWROUTE:
    rtm_name = "RTM_NEWROUTE";
    break;

  case RTM_DELROUTE:
    rtm_name = "RTM_DELROUTE";
    break;

  case RTM_GETROUTE:
    rtm_name = "RTM_GETROUTE";
    break;

  case RTM_NEWNEIGH:
    rtm_name = "RTM_NEWNEIGH";
    break;

  case RTM_DELNEIGH:
    rtm_name = "RTM_DELNEIGH";
    break;

  case RTM_GETNEIGH:
    rtm_name = "RTM_GETNEIG";
    break;

  case RTM_NEWRULE:
    rtm_name = "RTM_NEWRULE";
    break;

  case RTM_DELRULE:
    rtm_name = "RTM_DELRULE";
    break;

  case RTM_GETRULE:
    rtm_name = "RTM_GETRULE";
    break;

  case RTM_NEWQDISC:
    rtm_name = "RTM_NEWQDISC";
    break;

  case RTM_DELQDISC:
    rtm_name = "RTM_DELQDISC";
    break;

  case RTM_GETQDISC:
    rtm_name = "RTM_GETQDISC";
    break;

  case RTM_NEWTCLASS:
    rtm_name = "RTM_NEWTCLASS";
    break;

  case RTM_DELTCLASS:
    rtm_name = "RTM_DELTCLASS";
    break;

  case RTM_GETTCLASS:
    rtm_name = "RTM_GETTCLASS";
    break;

  case RTM_NEWTFILTER:
    rtm_name = "RTM_NEWTFILTER";
    break;

  case RTM_DELTFILTER:
    rtm_name = "RTM_DELTFILTER";
    break;

  case RTM_GETTFILTER:
    rtm_name = "RTM_GETTFILTER";
    break;

  case RTM_NEWACTION:
    rtm_name = "RTM_NEWACTION";
    break;

  case RTM_DELACTION:
    rtm_name = "RTM_DELACTION";
    break;

  case RTM_GETACTION:
    rtm_name = "RTM_GETACTION";
    break;

  case RTM_NEWPREFIX:
    rtm_name = "RTM_NEWPREFIX";
    break;

  case RTM_GETMULTICAST:
    rtm_name = "RTM_GETMULTICAST";
    break;

  case RTM_GETANYCAST:
    rtm_name = "RTM_GETANYCAST";
    break;

  case RTM_NEWNEIGHTBL:
    rtm_name = "RTM_NEWNEIGHTBL";
    break;

  case RTM_GETNEIGHTBL:
    rtm_name = "RTM_GETNEIGHTBL";
    break;

  case RTM_SETNEIGHTBL:
    rtm_name = "RTM_SETNEIGHTBL";
    break;

  case RTM_NEWNDUSEROPT:
    rtm_name = "RTM_NEWNDUSEROPT";
    break;

  case RTM_NEWADDRLABEL:
    rtm_name = "RTM_NEWADDRLABEL";
    break;

  case RTM_DELADDRLABEL:
    rtm_name = "RTM_DELADDRLABEL";
    break;

  case RTM_GETADDRLABEL:
    rtm_name = "RTM_GETADDRLABEL";
    break;

  case RTM_GETDCB:
    rtm_name = "RTM_GETDCB";
    break;

  case RTM_SETDCB:
    rtm_name = "RTM_SETDCB";
    break;

  case RTM_NEWNETCONF:
    rtm_name = "RTM_NEWNETCONF";
    break;

//  case RTM_DELNETCONF:
 //   rtm_name = "RTM_DELNETCONF";
  //  break;

  case RTM_GETNETCONF:
    rtm_name = "RTM_GETNETCONF";
    break;

  case RTM_NEWMDB:
    rtm_name = "RTM_NEWMDB";
    break;

  case RTM_DELMDB:
    rtm_name = "RTM_DELMDB";
    break;

  case RTM_GETMDB:
    rtm_name = "RTM_GETMDB";
    break;

  case RTM_NEWNSID:
    rtm_name = "RTM_NEWNSID";
    break;

  case RTM_DELNSID:
    rtm_name = "RTM_DELNSID";
    break;

  case RTM_GETNSID:
    rtm_name = "RTM_GETNSID";
    break;

  case RTM_NEWSTATS:
    rtm_name = "RTM_NEWSTATS";
    break;

  case RTM_GETSTATS:
    rtm_name = "RTM_GETSTATS";
    break;

/*  case RTM_NEWCACHEREPORT:
    rtm_name = "RTM_NEWCACHEREPORT";
    break; */

/*  case RTM_NEWCHAIN:
    rtm_name = "RTM_NEWCHAIN";
    break; */

/*  case RTM_DELCHAIN:
    rtm_name = "RTM_DELCHAIN";
    break; */

/*  case RTM_GETCHAIN:
    rtm_name = "RTM_GETCHAIN";
    break; */

/*  case RTM_NEWNEXTHOP:
    rtm_name = "RTM_NEWNEXTHOP";
    break; */

/*  case RTM_DELNEXTHOP:
    rtm_name = "RTM_DELNEXTHOP";
    break; */

/*  case RTM_GETNEXTHOP:
    rtm_name = "RTM_GETNEXTHOP";
    break; */

  default:
    rtm_name = "RTM_???";
    break;
  }

  return rtm_name;
}



