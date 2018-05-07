RPC-INTEGRATION ONBOARDING
~~~~~~~~~~~~~~~~~~~~~~~~~~

This guide will aquaint you with the tooling/access for the 
RPC-Integration team. You will learn what is required for access to
the lab environments that we use.

#. JIRA board: https://rpc-openstack.atlassian.net/projects/RI

#. RPC-Openstack repo: https://github.com/rcbops/rpc-openstack

#. Bastions access (pre-req for labs): https://one.rackspace.com/display/rackertools/Next+Gen+Bastions

   #. Request access to the "lnx-cbastion" LDAP group in RackerApp.

   #. SSH Config:
      
      .. code-block::
         
         Host cbast.dfw1.corp.rackspace.net
          User Racker-SSO-Name
          ProxyCommand none
          ForwardAgent yes
          ControlPath none
          KexAlgorithms diffie-hellman-group14-sha1
          MACs hmac-sha2-512

#. Phobos Access: https://github.com/rcbops/rpc-eng-ops/blob/master/docs/source/user_docs/accessing_phobos.rst
   
#. Lab Access: 
   
   #. Request from an RPC-Integration team member for your SSH key to be added to each of the lab's deploy box.

   #. Eureka:
         This lab environment is used mostly as our fast iterative development.
   
      #. In order to connect to Eureka, you need to SSH to the bastions.
              
         #. Execute this command FROM the bastions: ``ssh root@204.232.132.48 -p 2222``
         
         #. Documentation for Eureka:

            #. https://github.com/rcbops/rpc-eng-ops/blob/master/docs/source/deployment_plan/eureka-network.rst
            #. https://github.com/rcbops/rpc-eng-ops/blob/master/docs/source/deployment_plan/rpc-cluster-eureka.rst
   
   #. Deimos:
         This lab environment is used primarily for release candidate/soak tests.

      #. In order to connect to Deimos, you need to SSH to the bastions.
   
         #. Execute this command FROM the bastions: ``ssh root@204.232.132.48 -p 2224``

         #. Documentation for Deimos:

            #. https://github.com/rcbops/rpc-eng-ops/blob/master/docs/source/deployment_plan/deimos-network.rst
            #. https://github.com/rcbops/rpc-eng-ops/blob/master/docs/source/deployment_plan/rpc-cluster-deimos.rst
  
   #. Accessing the console of the nodes in the lab to troubleshoot/debug:

      #. Login to CORE: https://core.rackspace.com
      
      #. In the top right corner of the page, find the drop-down menu and choose "Computer"
         and put in the 6 digit device number (ex: 123456-infra01, 123456 is the device number)
      
      #. Click on Management Guidelines" -- find VPN details, setup/login to VPN.
      
      #. Click on "Details / Inventory" tab.
      
      #. Find section labeled "DRACNet" -- use the IP/Login info in a new window (must be on the Lab VPN).
      
      #. Once logged in, you can access the console by:
           
         #. Dell:

            #. Click Launch on the home screen -- console will download, follow prompts.
           
         #. HP:

            #. Click on Remote Console, click Web Start, console will download, follow prompts.

#. Upstream Openstack bug tracking: https://launchpad.openstack.org
   
   #. Upstream is switching to StoryBoard for bug tracking: https://storyboard.openstack.org

#. Upstream Contributing: https://wiki.openstack.org/wiki/How_To_Contribute


MAKING SURE YOU ARE READY TO CONTRIBUTE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#. Create a JIRA ticket under the RPC-Integration project named "test" and assign it to yourself.

#. Create a VM on Phobos.

#. Clone down RPC-Openstack, build an AIO from Master using the docs.
   
   https://github.com/rcbops/rpc-openstack#all-in-one-aio-deployment-quickstart

#. Log into Eureka and SSH into infra01.

#. Log into Deimos and SSH into infra01.
