  
## Understanding container networking using `linux network namespaces` and a `virtual switch` to isolate servers

#### Only commands will be found [here](https://github.com/faayam/linux-network-namespaces-hands-on/blob/main/ns-project.sh)

#### What is Linux Namespaces?
**_Linux namespace_** is an abstraction over resources in the operating system. We can think of a namespace as a box. Inside this box are these system resources, which ones exactly depend on the box’s (namespace’s) type. There are currently 7 types of namespaces `Cgroup`, `IPC`, `Network`, `Mount`, `PID`, `User`, `UTS`.

#### What is Network Namespaces?
Network namespaces, according to `man 7 network_namespaces`:

**_network namespaces provide isolation of the system resources associated with networking: network devices, IPv4 and IPv6 protocol stacks, IP routing tables, firewall rules, the /proc/net directory, the /sys/class/net directory, various files under /proc/sys/net, port numbers (sockets), and so on._**

#### Virtual Interfaces and Bridges:
**_Virtual interfaces_** provide us with virtualized representations of physical network interfaces; and the **_bridge_** gives us the virtual equivalent of a switch.

#### What are we going to cover?
- We are going to create two network namespace(like two isolated servers), two veth pair(like two physical ethernet cable) and a bridge (for routing traffic between namespaces).
- Then we will configure the bridge as the two namespaces can communicate with each other.
- Then we will connect the bridge to the host and the internet
- At last we will cofigure for incoming traffic(outside) to the namespace.

## Let's start...

**_Step 0:_** Check basic network status on host machine/root namespace. Just need to track the current status for better understanding. [I launch an ec2 instance(ubuntu) from AWS to simulate this hands-on. VM or even Normal linux machine are also okay.]
```bash
# list all the interfaces
sudo ip link

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
    link/ether 0a:1b:b1:bc:70:d0 brd ff:ff:ff:ff:ff:ff

# find the routing table
sudo route -n

Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.31.0.1      0.0.0.0         UG    100    0        0 eth0
172.31.0.0      0.0.0.0         255.255.240.0   U     0      0        0 eth0
172.31.0.1      0.0.0.0         255.255.255.255 UH    100    0        0 eth0
```
**_Step 1.1:_** Create two network namespace
```bash
# add two two network namespaces using "ip netns" command
sudo ip netns add ns1
sudo ip netns add ns2

# list the created network namespaces
sudo ip netns list

ns1
ns2

# By convention, network namespace handles created by
# iproute2 live under `/var/run/netns`
sudo ls /var/run/netns/

ns1 ns2
```
**_Step 1.2:_** By default, network interfaces of created netns are down, even loop interfaces. make them up.
```bash
sudo ip netns exec ns1 ip link set lo up
sudo ip netns exec ns1 ip link

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00

sudo ip netns exec ns2 ip link set lo up
sudo ip netns exec ns2 ip link

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
````

**_Step 2.1:_** Create a bridge network on the host
```bash
sudo ip link add br0 type bridge
# up the created bridge and check whether it is created and in UP/UNKNOWN state
sudo ip link set br0 up
sudo ip link

3: br0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether 12:38:75:40:c0:17 brd ff:ff:ff:ff:ff:ff
```
**_Step 2.2:_** Configure IP to the bridge network
```bash
sudo ip addr add 192.168.1.1/24 dev br0
# check whether the ip is configured and also ping to ensure
sudo ip addr

3: br0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 12:38:75:40:c0:17 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.1/24 scope global br0
       valid_lft forever preferred_lft forever
    inet6 fe80::1038:75ff:fe40:c017/64 scope link 
       valid_lft forever preferred_lft forever

ping -c 2 192.168.1.1

--- 192.168.1.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1026ms
rtt min/avg/max/mdev = 0.020/0.029/0.039/0.009 ms
```
**_Step 3.1:_** Create two veth interface for two network netns, then attach to the bridge and netns
```bash
# For ns1

# creating a veth pair which have two ends identical veth0 and ceth0
sudo ip link add veth0 type veth peer name ceth0
# connect veth0 end to the bridge br0
sudo ip link set veth0 master br0
# up the veth0 
sudo ip link set veth0 up 
# connect ceth0 end to the netns ns1
sudo ip link set ceth0 netns ns1
# up the ceth0 using 'exec' to run command inside netns
sudo ip netns exec ns1 ip link set ceth0 up
# check the link status 
sudo ip link

3: br0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 9a:af:0d:89:8b:81 brd ff:ff:ff:ff:ff:ff
5: veth0@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br0 state UP mode DEFAULT group default qlen 1000
    link/ether 9a:af:0d:89:8b:81 brd ff:ff:ff:ff:ff:ff link-netns ns1

# check the link status inside ns1
sudo ip netns exec ns1 ip link

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
4: ceth0@if5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 3e:66:e5:b6:07:9a brd ff:ff:ff:ff:ff:ff link-netnsid 0


# For ns2; do the same as ns1

sudo ip link add veth1 type veth peer name ceth1
sudo ip link set veth1 master br0
sudo ip link set veth1 up
sudo ip link set ceth1 netns ns2
sudo ip netns exec ns2 ip link set ceth1 up

sudo ip link 

3: br0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 1a:f5:b2:8e:ca:a5 brd ff:ff:ff:ff:ff:ff
5: veth0@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br0 state UP mode DEFAULT group default qlen 1000
    link/ether 9a:af:0d:89:8b:81 brd ff:ff:ff:ff:ff:ff link-netns ns1
7: veth1@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br0 state UP mode DEFAULT group default qlen 1000
    link/ether 1a:f5:b2:8e:ca:a5 brd ff:ff:ff:ff:ff:ff link-netns ns2
    
sudo ip netns exec ns2 ip link

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
6: ceth1@if7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 3e:1e:48:de:47:07 brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

**_Step 3.2:_** Now we will we add ip address to the netns veth interfaces and update route table to establish communication with bridge network and it will also allow communication between two netns via bridge; 
```bash
# For ns1
sudo ip netns exec ns1 ip addr add 192.168.1.10/24 dev ceth0
sudo ip netns exec ns1 ping -c 2 192.168.1.10
sudo ip netns exec ns1 ip route
 
192.168.1.0/24 dev ceth0 proto kernel scope link src 192.168.1.10
# check if you can reach bridge interface
sudo ip netns exec ns1 ping -c 2 192.168.1.1

--- 192.168.1.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1020ms
rtt min/avg/max/mdev = 0.046/0.050/0.054/0.004 ms

# For ns2
sudo ip netns exec ns2 ip addr add 192.168.1.11/24 dev ceth1
sudo ip netns exec ns2 ping -c 2 192.168.1.11
sudo ip netns exec ns2 ip route 

192.168.1.0/24 dev ceth1 proto kernel scope link src 192.168.1.11
# check if you can reach bridge interface
sudo ip netns exec ns2 ping -c 2 192.168.1.1

--- 192.168.1.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1020ms
rtt min/avg/max/mdev = 0.046/0.050/0.054/0.004 ms
```

**_Step 4:_** Verify connectivity between two netns and it should work!
```bash
# For ns1: 
# we can log in to netns environment using below; 
# it will be totally isolated from any other network
sudo nsenter --net=/var/run/netns/ns1
# ping to the ns2 netns to verify the connectivity
ping -c 2 192.168.1.11

--- 192.168.1.11 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1019ms
rtt min/avg/max/mdev = 0.033/0.042/0.051/0.009 ms
# exit from the ns1
exit
# For ns2
sudo nsenter --net=/var/run/netns/ns2
# ping to the ns1 netns to verify the connectivity
ping -c 2 192.168.1.10

--- 192.168.1.10 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1022ms
rtt min/avg/max/mdev = 0.041/0.044/0.048/0.003 ms
# exit from the ns2
exit
```
#### Connectivity between two network namespaces via bridge is completed.

![Project Diagram](https://github.com/faayam/linux-network-namespaces-hands-on/blob/main/namespace-setup.png)

_the diagrom is taken from ops.tips blog_

**_Step 5.1:_** Now it's time to connect to the internet. As we saw routing table from `ns1` doesn’t have a default gateway, it can’t reach any other machine from outside the `192.168.1.0/24` range.
```bash
sudo ip netns exec ns1 ping -c 2 8.8.8.8
ping: connect: Network is unreachable
# check the route inside ns1
sudo ip netns exec ns1 route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
192.168.1.0     0.0.0.0         255.255.255.0   U     0      0        0 ceth0
# As we can see, no route is defined to carry other traffic than 192.168.1.0/24
# we can fix this by using adding default route 
sudo ip netns exec ns1 ip route add default via 192.168.1.1
sudo ip netns exec ns1 route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.1.1     0.0.0.0         UG    0      0        0 ceth0
192.168.1.0     0.0.0.0         255.255.255.0   U     0      0        0 ceth0

# Do the same for ns2
sudo ip netns exec ns2 ip route add default via 192.168.1.1
sudo ip netns exec ns2 route -n

Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.1.1     0.0.0.0         UG    0      0        0 ceth1
192.168.1.0     0.0.0.0         255.255.255.0   U     0      0        0 ceth1

# now first ping the host machine eth0
ip addr | grep eth0

2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
    inet 172.31.13.55/20 brd 172.31.15.255 scope global dynamic eth0
# ping from ns1 to host ip
sudo ip netns exec ns1 ping 172.31.13.55
64 bytes from 172.31.13.55: icmp_seq=1 ttl=64 time=0.037 ms
64 bytes from 172.31.13.55: icmp_seq=2 ttl=64 time=0.036 ms
# we get the response from host machine eth0
```
**_Step 5.2:_** Now let's see if ns1 can communicate to the internet, we can analysis traffic using tcpdump to see how a packet will travel. Open another terminal for catching traffic using tcpdump.
```bash
# terminal-1
# now trying to ping 8.8.8.8 again
sudo ip netns exec ns1 ping 8.8.8.8

# still unreachable
# terminal 2
# open tcpdump in eth0 to see the packet
sudo tcpdump -i eth0 icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes

# no packet captured, let's capture traffic for br0
sudo tcpdump -i br0 icmp

tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on br0, link-type EN10MB (Ethernet), capture size 262144 bytes
02:17:30.807072 IP ip-192-168-1-10.ap-south-1.compute.internal > dns.google: ICMP echo request, id 17506, seq 1, length 64
02:17:31.829317 IP ip-192-168-1-10.ap-south-1.compute.internal > dns.google: ICMP echo request, id 17506, seq 2, length 64

# we can see the traffic at br0 but we don't get response from eth0.
# it's because of IP forwarding issue
sudo cat /proc/sys/net/ipv4/ip_forward
0

# enabling ip forwarding by change value 0 to 1
sudo sysctl -w net.ipv4.ip_forward=1
sudo cat /proc/sys/net/ipv4/ip_forward
1

# terminal-2
sudo tcpdump -i eth0 icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
02:30:12.603895 IP ip-192-168-1-10.ap-south-1.compute.internal > dns.google: ICMP echo request, id 18103, seq 1, length 64
02:30:13.621367 IP ip-192-168-1-10.ap-south-1.compute.internal > dns.google: ICMP echo request, id 18103, seq 2, length 64
# as we can see now we are getting response eth0
# but ping 8.8.8.8 still not working
# Although the network is now reachable, there’s no way that 
# we can have responses back - cause packets from external networks 
# can’t be sent directly to our `192.168.1.0/24` network.
```
**_Step 5.3:_** To get around that, we can make use of NAT (network address translation) by placing an `iptables` rule in the `POSTROUTING` chain of the `nat` table.
```bash
sudo iptables \
        -t nat \
        -A POSTROUTING \
        -s 192.168.1.0/24 ! -o br0 \
        -j MASQUERADE
# -t specifies the table to which the commands
# should be directed to. By default it's `filter`.
# -A specifies that we're appending a rule to the
# chain then we tell the name after it;
# -s specifies a source address (with a mask in this case).
# -j specifies the target to jump to (what action to take).

# now we're getting response from google dns
sudo ip netns exec ns1 ping -c 2 8.8.8.8

--- 8.8.8.8 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 1.625/1.662/1.700/0.037 ms
```

**_Step: 6_** Now let's open a service in one of the namespaces and try to get response from outside
```bash
sudo nsenter --net=/var/run/netns/netns1
python3 -m http.server --bind 192.168.1.10 3000
```
As I have a ec2 instance from AWS, it have an attached public IP. I will try to reach that IP with specific port from outside. 
```bash
telnet 65.2.35.192 5000
Trying 65.2.35.192...
telnet: Unable to connect to remote host: Connection refused
```
As we can see we can't reach the destination. Because we didn'i tell the Host machine where to put the incoming traffic. We have to NAT again, this time we will define the destination.
```bash

sudo iptables \
        -t nat \
        -A PREROUTING \
        -d 172.31.13.55 \
        -p tcp -m tcp --dport 5000 \
        -j DNAT --to-destination 192.168.1.10:5000
# -p specifies a port type and --dport specifies the destination port
# -j specifies the target DNAT to jump to destination IP with port.


# from my laptop
# now I can connect the destination with port.
# We successfully recieved traffic from internet inside container network

telnet 65.2.35.192 5000
Trying 65.2.35.192...
Connected to 65.2.35.192.
Escape character is '^]'.
```

#### Now the hands on completed; What we achieve:
- the host can send traffic to any application inside network namespaces 
- the application inside network namespaces can comunicate with host applications and another network namespaces applications
- an application inside the network namespaces can connect to the internet
- an application inside the network namespaces can listen for request from the outside internet
- Finally we understand how Docker or some other container tool done networking under the hood. They automate the whole process for us when we give command like "Docker run -p 5000:5000 frontend-app"

#### Resources
- https://man7.org/linux/man-pages/man7/network_namespaces.7.html
- https://ops.tips/blog/using-network-namespaces-and-bridge-to-isolate-servers/
- https://github.com/dipanjal/DevOps/tree/main/NetNS_Ingress_Egress_Traffic
- https://man7.org/linux/man-pages/man8/iptables.8.html

