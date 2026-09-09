#!/usr/bin/env python3

import argparse
import socket
import struct

IFACE = "eth2"
ETHERTYPE = 0x88B5


def get_mac_address(iface):
    with open(f"/sys/class/net/{iface}/address", "r") as f:
        return bytes.fromhex(f.read().strip().replace(":", ""))


def build_frame(seq, iface):
    # seq == Ethernet frame length (FCS excluded)
    frame_len = seq

    dst = b"\xff\xff\xff\xff\xff\xff"
    src = get_mac_address(iface)
    ethertype = struct.pack("!H", ETHERTYPE)

    header = dst + src + ethertype
    payload_len = frame_len - len(header)

    signature = f"SEQ={seq:04d} LEN={frame_len:04d} ".encode("ascii")

    if payload_len < len(signature):
        raise ValueError(
            f"Frame length {frame_len} is too short "
            f"(minimum for signature is {len(header) + len(signature)} bytes)"
        )

    # Low 8 bits of seq are repeated through the remaining payload.
    fill_byte = seq & 0xff
    payload = signature + bytes([fill_byte]) * (payload_len - len(signature))

    frame = header + payload
    assert len(frame) == frame_len

    return frame


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Send one sequence-tagged raw Ethernet frame. "
            "The sequence number is also the frame length."
        )
    )
    parser.add_argument(
        "seq",
        type=int,
        help="sequence number and Ethernet frame length, e.g. 65",
    )
    parser.add_argument(
        "-i", "--interface",
        default=IFACE,
        help=f"interface (default: {IFACE})",
    )
    args = parser.parse_args()

    frame = build_frame(args.seq, args.interface)

    sock = socket.socket(socket.AF_PACKET, socket.SOCK_RAW)
    try:
        sock.bind((args.interface, 0))
        sent = sock.send(frame)
    finally:
        sock.close()

    print(
        f"sent seq={args.seq} "
        f"frame_len={len(frame)} "
        f"payload_len={len(frame) - 14} "
        f"ethertype=0x{ETHERTYPE:04x} "
        f"interface={args.interface} "
        f"bytes_sent={sent}"
    )


if __name__ == "__main__":
    main()
