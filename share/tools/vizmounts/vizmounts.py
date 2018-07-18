#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.

import logging
import argparse
import sys

#logging.basicConfig(level=logging.DEBUG)


class Mounts:
    def __init__(self):
        self.mounts = []

    def add_fstab(self, fstab_file, jail=None, internal=False):
        with open(fstab_file) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                try:
                    dev, point, typ, opts = line.split()[:4]
                except ValueError as e:
                    print("Unable to parse line in {}:".format(fstab_file))
                    print(line)
                    continue
                opts = opts.split(',')
                self.mounts.append({
                    "jail": jail,
                    "internal": internal,
                    "dev": dev,
                    "point": point,
                    "type": typ,
                    "opts": opts,
                    "bind": "bind" in opts,
                })

    def to_text(self):
        def format_mount(m):
            if m["bind"]:
                return "{dev:>35} -------------> {point}".format(**m)
            else:
                return "{dev:>35} -{type:-^12}> {point}".format(**m)
        return '\n'.join(map(format_mount, self.mounts))

    def to_dot(self, with_legend=None):
        df = DotFormatter()
        if with_legend is not None:
            df.with_legend = with_legend
        return df.to_dot(self.mounts)


class Color:
    colors = ["black", "red", "blue", "darkgreen", "darkviolet", "brown"]
    jail_colors = {}

    @classmethod
    def set_colors(cls, colors):
        cls.colors = colors

    @classmethod
    def of(cls, jail):
        try:
            return cls.jail_colors[jail]
        except KeyError:
            next_color = cls.colors.pop(0)
            cls.colors.append(next_color)
            cls.jail_colors[jail] = next_color
            return next_color


class Node():
    count = 0

    def __init__(self, name, parent, jail=None):
        self.name = name
        self.jail = jail
        self.parent = parent
        self.children = {}
        self.device = None
        self.fstype = None
        self._make_path()
        self.node_number = Node.count
        self.node_id = "node{}_{}_{}".format(Node.count, jail, self.path.replace("/", "_").replace(".", "_").replace('-', '_'))
        self.visited = False
        Node.count += 1

    def _make_path(self):
        if self.parent:
            self.path = "{}/{}".format(self.parent.path.rstrip('/'), self.name)
        else:
            self.path = self.name

    def get_child(self, child_name, jail=None):
        # check if child exists in jail children
        if jail:
            try:
                jail_children = self.children[jail]
                if child_name in jail_children:
                    return jail_children[child_name]
            except KeyError:
                self.children[jail] = {}
        # if not, check if it exists in no-jail children
        try:
            nojail_children = self.children[None]
            if child_name in nojail_children:
                return nojail_children[child_name]
        except KeyError:
            self.children[None] = {}
        # if not, create it in jail children
        child = Node(child_name, self, jail=jail)
        child_tuple = ("path", child, [])
        self.children[jail][child_name] = child_tuple
        return child_tuple

    def add_bind_child(self, name, jail, child, opts):
        try:
            jail_children = self.children[jail]
        except KeyError:
            jail_children = {}
            self.children[jail] = jail_children
        try:
            if jail_children[name][1].children:
                logging.warn("{} in jail {} bind-mounted in non-empty directory".format(child.path, jail))
        except KeyError:
            pass
        jail_children[name] = ("bind", child, opts)

    def __repr__(self):
        return u"<Node{} {}:{}, children: {}".format(self.node_number, self.jail, self.path, list(self.children.keys()))


class DotFormatter:
    legend = """
subgraph cluster_legend {
    label = "Légende";
    subgraph cluster_1 {
        label="";
        style = dotted;
        root [shape="record", label="{ / | /dev/sda1 | ext4 }"];
        desc1 [shape=plaintext, label="Ce point de montage\nest le device /dev/sda1,\nmonté sur / en ext4"];
    }

    subgraph cluster_2 {
        label="";
        style = dotted;
        jails [shape="record", label="{ jails | /dev/sdb1 | btrfs }"];
        desc2 [shape=plaintext, label="Le device /dev/sdb1\nest monté dans\n/mounts/jails"];
    }

    root -> mounts -> jails -> www;
    www -> srv -> http;
    www -> var;

    subgraph cluster_3 {
        label="";
        style = dotted;
        desc3 [shape=plaintext, label="Dans le socle et dans la cage,\n/srv/http est monté en bind sur /var/www"];
        var -> http [style=dashed, headlabel="www"];
    }

    subgraph cluster_4 {
        label="";
        style = dotted;
        desc4 [shape=plaintext, label="Racine de la cage www"];
        www_jail [style=dashed, color=red, label=www];
        www_jail -> www [style=dashed, color=red, headlabel="/"];
    }

    subgraph cluster_5 {
        label="";
        style = dotted;
        desc5 [shape=plaintext, label="Dans la cage www,\n/bin du socle est monté\nen bind read-only\net /etc en noexec\ndans les mêmes répertoires"];
        root -> bin;
        root -> etc;
        www -> bin [style=dashed, color=red, arrowhead=onormalodot];
        www -> etc [style=dashed, color=red, arrowhead=onormalodiamond];
    }
}
    """

    def __init__(self):
        self.roots = {None: Node("/", None)}
        self.additional_nodes = []
        self.nmounts = 0
        self.with_legend = True

    def get_node(self, path, start=None, jail=None):
        logging.debug("get_node: {} in jail {}".format(path, jail))
        if start is None:
            try:
                start = self.roots[jail]
            except KeyError:
                start = self.roots[None]
                self.roots[jail] = start
        path = path.lstrip("/").split('/', 1)
        path_el = path[0]
        try:
            path_remainder = path[1]
        except IndexError:
            path_remainder = None
        next_node_type, next_node, next_node_opts = start.get_child(path_el, jail)
        if path_remainder:
            return self.get_node(path_remainder, start=next_node, jail=jail)
        else:
            return next_node

    def bind_nodes(self, dev, point, jail, opts):
        logging.debug("bind_nodes: {} -> {} in {}".format(point, dev, jail))
        point.parent.add_bind_child(point.name, jail, dev, opts)

    def add_root_mount(self, mount):
        jail = mount["jail"]
        if jail:
            self.roots[jail] = self.get_node(mount["dev"])
        else:
            self.roots[None].device = mount["dev"]
            self.roots[None].fstype = mount["type"]

    def add_additional_mount(self, mount):
        new_node = Node(mount["point"], None)
        new_node.device = mount["dev"]
        new_node.fstype = mount["type"]
        self.additional_nodes.append(new_node)

    def add_mount(self, mount):
        logging.debug("add_mount: {dev}, {point}, {type}, {bind}".format(**mount))
        self.nmounts += 1
        if mount["point"] == "/":
            self.add_root_mount(mount)
            return
        if not mount["point"].startswith("/"):
            self.add_additional_mount(mount)
            return
        if mount["bind"]:
            if mount["internal"]:
                devjail = mount["jail"]
            else:
                devjail = None
            dev = self.get_node(mount["dev"], jail=devjail)
            point = self.get_node(mount["point"], jail=mount["jail"])
            self.bind_nodes(dev, point, mount["jail"], mount["opts"])
        else:
            point = self.get_node(mount["point"], jail=mount["jail"])
            point.device = mount["dev"]
            point.fstype = mount["type"]

    def output_node_dot(self, node):
        if node.visited:
            return
        node.visited = True
        logging.debug("output_node_dot: {}".format(node))
        attrs = []
        attrs.append('color="{}"'.format(Color.of(node.jail)))
        if node.jail and node.name == "/":
            full_name = "{} ({})".format(node.name, node.jail)
        else:
            full_name = "{}".format(node.name)
        if node.device:
            attrs.append('shape="record"')
            attrs.append('label="{{ {} | {} | {} }}"'.format(full_name, node.device, node.fstype))
        else:
            attrs.append('label="{}"'.format(full_name))
        attrs = "[" + ",".join(attrs) + "]"
        self.dot += '{} {};\n'.format(node.node_id, attrs)
        for jail, jail_children in node.children.items():
            for child_name, (child_node_type, child_node, child_opts) in jail_children.items():
                attrs = []
                attrs.append('color="{}"'.format(Color.of(jail)))
                if child_node_type == "bind":
                    attrs.append('style="dashed"')
                    if child_name != child_node.name:
                        attrs.append('headlabel="{}"'.format(child_name))
                arrowhead = "onormal"
                if "ro" in child_opts:
                    arrowhead += "odot"
                if "noexec" in child_opts:
                    arrowhead += "odiamond"
                attrs.append('arrowhead="{}"'.format(arrowhead))
                if attrs:
                    attrs = "[" + ",".join(attrs) + "]"
                else:
                    attrs = ""
                self.dot += "{} -> {} {};\n".format(node.node_id, child_node.node_id, attrs)
                self.output_node_dot(child_node)


    def output_jail_roots(self, jail_roots):
        for jail, root in jail_roots.items():
            node_id = jail + "_jail_root"
            self.dot += '{} [label="{}", style="dashed", color="{}"];\n'.format(node_id, jail, Color.of(jail))
            self.dot += '{} -> {} [style="dashed", headlabel="/", color="{}"];\n'.format(node_id, root.node_id, Color.of(jail))

    def output_dot(self):
        self.dot = "digraph mounts {\n"
        self.dot += 'edge [arrowhead="empty"];\n'
        if self.with_legend:
            self.dot += self.legend

        if self.nmounts: # if no mounts were added, we're just outputting the legend
            self.output_node_dot(self.roots.pop(None))
            self.output_jail_roots(self.roots)

            # swaps...
            for node in self.additional_nodes:
                self.output_node_dot(node)

        self.dot += "}"
        return self.dot

    def to_dot(self, mounts):
        for mount in mounts:
            self.add_mount(mount)
        return self.output_dot()


def main():
    parser = argparse.ArgumentParser(description="Parses fstabs and outputs corresponding DOT-format graph of mounts")
    parser.add_argument("--fstab", "-f", nargs="+", action="append", default=[],
                         help="Add an fstab. First argument is the filename and is mandatory. Second argument is the optional name of a jail, third is optionally the keyword 'internal' if this fstab is internal to the jail. This option can be specified more than once. Order matters.")
    parser.add_argument("--legend", "-l", action="store_true",
                          help="Output the legend. Can be used alone or with --fstab options.")
    parser.add_argument("--colors", "-c", nargs="+",
                        help="Colors to use for the jails, instead of the default ones.")

    args = parser.parse_args()
    
    if args.colors:
        Color.set_colors(args.colors)
    mounts = Mounts()

    for fstab in args.fstab:
        if len(fstab) > 3:
            parser.print_help()
            sys.exit(1)
        if len(fstab) == 3:
            if fstab[2] != "internal":
                parser.print_help()
                sys.exit(1)
            mounts.add_fstab(fstab[0], fstab[1], True)
        if len(fstab) == 2:
            mounts.add_fstab(fstab[0], fstab[1])
        else:
            mounts.add_fstab(fstab[0])

    print(mounts.to_dot(with_legend=args.legend))

if __name__ == "__main__":
    main()
