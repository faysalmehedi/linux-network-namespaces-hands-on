
# Step 0: Check basic network status on host machine/root namespace

sudo ip link
sudo ip route
sudo route -n
sudo lsns
sudo ip netns list

# Step 1: Create a bridge network and attach ip to that interface

sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip addr add 192.168.1.1/24 dev br0
sudo ip addr

ping 192.168.1.1

# Step 2: Create two network namespace

sudo ip netns add ns1
sudo ip netns add ns2
sudo ip netns list
sudo ls /var/run/netns/


sudo ip netns exec ns1 ip link set lo up
sudo ip netns exec ns1 ip link

sudo ip netns exec ns2 ip link set lo up
sudo ip netns exec ns2 ip link

# Step 3: create two veth interface for two network ns

# For ns1:

sudo ip link add veth0 type veth peer name ceth0
sudo ip link set veth0 master br0
sudo ip link set veth0 up
sudo ip link 
sudo ip link set ceth0 netns ns1
sudo ip netns exec ns1 ip link set ceth0 up

sudo ip netns exec ns1 ip addr add 192.168.1.10/24 dev ceth0
sudo ip netns exec ns1 ping 192.168.1.10
sudo ip netns exec ns1 ip route add default via 192.168.1.1/24
sudo ip netns exec ns1 ip route 
sudo ip netns exec ns1 ping 192.168.1.1

# For ns2:

sudo ip link add veth1 type veth peer name ceth1
sudo ip link set veth1 master br0
sudo ip link set veth1 up
sudo ip link 
sudo ip link set ceth1 netns ns2
sudo ip netns exec ns2 ip link set ceth1 up

sudo ip netns exec ns2 ip addr add 192.168.1.11/24 dev ceth1
sudo ip netns exec ns2 ping 192.168.1.11
sudo ip netns exec ns2 ip route add default via 192.168.1.1/24 
sudo ip netns exec ns2 ip route 
sudo ip netns exec ns2 ping 192.168.1.1

# Step 5: Test network Connectivity between two network namespace

# from ns1: 

sudo nsenter --net=/var/run/netns/ns1
ping -c -2 192.168.1.10
ping -c -2 192.168.1.1
ping -c -2 192.168.1.11
ping -c -2 host ip

# from ns2: 

sudo nsenter --net=/var/run/netns/ns2
ping -c -2 192.168.1.11
ping -c -2 192.168.1.1
ping -c -2 192.168.1.10
ping host ip

# Step 6: Connect to the internet

# sudo iptables -t nat -A POSTROUTING -s 192.168.1.0/24 ! -o br0 -j MASQUERADE
sudo iptables \
        -t nat \
        -A POSTROUTING \
        -s 192.168.1.0/24 \
        -j MASQUERADE

#To get around that, we can make use of NAT (network address translation) 
# by placing an iptables rule in the POSTROUTING chain of the nat table:

# -t specifies the table to which the commands
# should be directed to. By default it's `filter`.
#
# -A specifies that we're appending a rule to the
# chain the we tell the name after it;
#
# -s specifies a source address (with a mask in 
# this case).
#
# -j specifies the target to jump to (what action to
# take).

sudo ip netns exec ns1 ping 8.8.8.8
sudo ip netns exec ns2 ping 8.8.8.8

# step 7: listen for the requests

sudo nsenter --net=/var/run/netns/netns1
python3 -m http.server --bind 192.168.1.10 5000

# sudo iptables -t nat -A PREROUTING -d 172.31.13.55 -p tcp -m tcp --dport 5000 -j DNAT --to-destination 192.168.1.10:5000

sudo iptables \
        -t nat \
        -A PREROUTING \
        -d 172.31.13.55 \
        -p tcp -m tcp \
        --dport 5000 \
        -j DNAT --to-destination 192.168.1.10/24



