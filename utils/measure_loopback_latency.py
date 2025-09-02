import ctypes
import fcntl
import numpy
import select
import struct
import time
from matplotlib import pyplot as plt
from socket import socket, htons, AF_PACKET, SOCK_RAW, SOL_SOCKET, MSG_ERRQUEUE

INTERFACE1 = "enp7s0"
INTERFACE2 = "enp7s0d1"
DEST_MAC_ADDR = 0x011B19000000
SRC_MAC_ADDR = 0xAABBCCDDEEFF
PTP_ETH_TYPE = 0x88F7

SIOCSHWTSTAMP = 0x89b0
HWTSTAMP_TX_OFF = 0
HWTSTAMP_TX_ON = 1
HWTSTAMP_FILTER_NONE = 0
HWTSTAMP_FILTER_ALL = 1

SO_TIMESTAMPING = 37
SOF_TIMESTAMPING_TX_HARDWARE = 1 << 0
SOF_TIMESTAMPING_RX_HARDWARE = 1 << 2
SOF_TIMESTAMPING_RAW_HARDWARE = 1 << 6

def main():
    enable_hardware_timestamp(INTERFACE1)
    enable_hardware_timestamp(INTERFACE2)
    time.sleep(3)

    # create source socket
    src_sock = socket(AF_PACKET, SOCK_RAW, htons(PTP_ETH_TYPE))
    # enable hardware timestamping sockopt
    timestamp_flags = SOF_TIMESTAMPING_TX_HARDWARE | SOF_TIMESTAMPING_RX_HARDWARE | SOF_TIMESTAMPING_RAW_HARDWARE
    src_sock.setsockopt(SOL_SOCKET, SO_TIMESTAMPING, timestamp_flags)
    # bind to interface 1
    src_sock.bind((INTERFACE1, PTP_ETH_TYPE))

    # create destination socket
    dest_sock = socket(AF_PACKET, SOCK_RAW, htons(PTP_ETH_TYPE))
    # enable hardware timestamping sockopt
    timestamp_flags = SOF_TIMESTAMPING_RX_HARDWARE | SOF_TIMESTAMPING_RAW_HARDWARE
    dest_sock.setsockopt(SOL_SOCKET, SO_TIMESTAMPING, timestamp_flags)
    # bind to interface 2
    dest_sock.bind((INTERFACE2, PTP_ETH_TYPE))


    latencies = []
    for _ in range(100000):
        # craft and send PTP sync packet
        ptp_frame = gen_ptp_packet()
        src_sock.send(ptp_frame)
        # retrieve TX timestamp from NIC
        select.select([src_sock], [], [], 1)
        msg, ancdata, flags, addr = src_sock.recvmsg(1024, 1024, MSG_ERRQUEUE)

        for level, cmsg_type, cmsg_data in ancdata:
            if level == SOL_SOCKET and cmsg_type == SO_TIMESTAMPING:
                tv_sec, tv_nsec, _, _, hw_tv_sec, hw_tv_nsec = struct.unpack('ll' * 3, cmsg_data[:48])
                tx_timestamp = hw_tv_nsec
                print(f"TX Hardware timestamp: {tx_timestamp} nanoseconds")
                break

        msg, ancdata, flags, addr = dest_sock.recvmsg(1024, 1024)
        for level, cmsg_type, cmsg_data in ancdata:
            if level == SOL_SOCKET and cmsg_type == SO_TIMESTAMPING:
                tv_sec, tv_nsec, _, _, hw_tv_sec, hw_tv_nsec = struct.unpack('ll' * 3, cmsg_data[:48])
                rx_timestamp = hw_tv_nsec
                print(f"RX Hardware timestamp: {rx_timestamp} nanoseconds")
                break

        if rx_timestamp < tx_timestamp: # crossed 1s boundary
            continue
        latency = rx_timestamp - tx_timestamp
        latencies.append(latency)
        print(f"Difference: {latency} nanoseconds")


    latencies = numpy.array(latencies)
    avg = numpy.mean(latencies)
    std = numpy.std(latencies)
    p5 = numpy.percentile(latencies, 5)
    p50 = numpy.percentile(latencies, 50)
    p95 = numpy.percentile(latencies, 95)
    p99 = numpy.percentile(latencies, 99)
    min = numpy.min(latencies)
    max = numpy.max(latencies)

    stats = f"Average:          {avg:.0f} ns\n" \
          + f"Standard Dev.:    {std:.0f} ns\n" \
          + f"5th percentile:   {p5:.0f} ns\n" \
          + f"50th percentile:  {p50:.0f} ns\n" \
          + f"95th percentile:  {p95:.0f} ns\n" \
          + f"99th percentile:  {p99:.0f} ns\n" \
          + f"Min:              {min:.0f} ns\n" \
          + f"Max:              {max:.0f} ns"

    print("====== Latency results ======")
    print(stats)


    x = numpy.arange(len(latencies))
    fig = plt.figure(figsize=(8, 6))
    plt.scatter(x, latencies, color='b', s=1)
    plt.title("One Way Delay (loopback)")
    plt.xlabel("Packet")
    plt.ylabel("Latency (ns)")
    plt.axis("tight")
    plt.text(0.62, 0.85, stats, transform=fig.transFigure, fontfamily='monospace',
        verticalalignment='top',
        horizontalalignment='left',
        bbox=dict(facecolor='white', alpha=0.8)
    )
    plt.savefig("loopback_timeseries.png")

    sorted_latencies = numpy.sort(latencies)
    filtered_latencies = sorted_latencies[sorted_latencies < 6000]
    fig = plt.figure(figsize=(8, 6))
    plt.hist(filtered_latencies, bins=100, color='skyblue', edgecolor='black', alpha=0.6)
    plt.yscale('log')
    plt.title("One Way Delay (loopback)")
    plt.xlabel("Latency (ns)")
    plt.ylabel("Frequency (log)")
    plt.axis("tight")
    plt.text(0.62, 0.85, stats, transform=fig.transFigure, fontfamily='monospace',
        verticalalignment='top',
        horizontalalignment='left',
        bbox=dict(facecolor='white', alpha=0.8)
    )
    plt.savefig("loopback_distribution.png")




def gen_ptp_packet():
    dest = DEST_MAC_ADDR.to_bytes(6) # PTP multicast
    src = SRC_MAC_ADDR.to_bytes(6)
    ethtyp = PTP_ETH_TYPE.to_bytes(2)

    msgtyp = (0x1<<4 | 0x0).to_bytes(1) # 802.1AS, sync
    verptp = (0x0<<4 | 0x2).to_bytes(1) # PTPv2
    msglen = 0x2e.to_bytes(2)
    domain = 0x0.to_bytes(1)
    reserved1 = 0x0.to_bytes(1)
    flag = 0x0.to_bytes(2)
    correction = 0x0.to_bytes(8)
    reserved2 = 0x0.to_bytes(4)
    clockid = 0x7cfe90fffe91fa20.to_bytes(8)
    src_portid = 0x1.to_bytes(2)
    seq_id = 0x0.to_bytes(2)
    ctrl = 0x0.to_bytes(1) # sync
    logint = 0x0.to_bytes(1)
    origin_ts = 0x0.to_bytes(6)
    origin_tx_ns = 0x0.to_bytes(4)

    packet = msgtyp + verptp + msglen + domain + reserved1 + flag + correction + reserved2 + clockid + src_portid + seq_id + ctrl + logint + origin_ts + origin_tx_ns
    full_payload = packet.ljust(46, b"\x00")

    frame = dest + src + ethtyp + full_payload
    return frame


def enable_hardware_timestamp(interface):
    # alternatively run hwstamp_ctl -i <interface> -t 1 -r 1
    config = HWTSTAMP_CONFIG()
    config.flags = 0
    config.tx_type = HWTSTAMP_TX_ON
    config.rx_filter = HWTSTAMP_FILTER_ALL

    ifreq = struct.pack(
        f"16sP",
        interface.encode("utf-8"),
        ctypes.addressof(config)
    )

    sock = socket(AF_PACKET, SOCK_RAW)
    fcntl.ioctl(sock, SIOCSHWTSTAMP, ifreq)
    sock.close()


class HWTSTAMP_CONFIG(ctypes.Structure):
    _fields_ = [
        ("flags", ctypes.c_int),
        ("tx_type", ctypes.c_int),
        ("rx_filter", ctypes.c_int),
    ]

if __name__ == "__main__":
    main()