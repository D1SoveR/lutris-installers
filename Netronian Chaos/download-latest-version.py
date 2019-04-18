#!/usr/bin/env python3

import html.parser
import re
import sys
import urllib.request
import urllib.parse

FORUM_URL = "https://forum.zdoom.org/viewtopic.php?f=43&t=57964"

def main(destination_file):

	print("Attempting to identify latest version of Netronian Chaos...")

	# Attempt to retrieve the HTML page of ZDoom forum post
	with urllib.request.urlopen(FORUM_URL) as response:
		parser = ZDoomForumPostParser()
		links_list = parser.feed(response.read().decode("utf-8"))

	# Attempt to determine what the latest version of Netronian Chaos is;
	# do so by processing by version numbers in the links
	version_regex = re.compile(r"(?<=v\.)([\d\.]+)(?=\.zip)")
	netronian_links_map = { float(k.group(0)): v for (k, v) in zip(map(version_regex.search, links_list), links_list) if k }
	latest_version = max(*netronian_links_map.keys())

	print("Found v{0} to be the latest, attempting to download it...\n".format(latest_version))

	# Attempt to retrieve the download link from Mediafire page
	with urllib.request.urlopen(netronian_links_map[latest_version]) as response:
		parser = MediafireDownloadParser()
		download_link = parser.feed(response.read().decode("utf-8"))

	# Attempt to download the file
	if download_link:
		request = urllib.request.Request(download_link, headers={ "Referer": netronian_links_map[latest_version] })
		with urllib.request.urlopen(request) as response:

			current_size = 0
			total_size = dict(response.getheaders()).get("Content-Length", None)

			if total_size is not None:
				total_size = toMB(int(total_size))
			else:
				print("Progress: [ UNKNOWN ]", end="\r")

			with open(destination_file, mode="wb") as fp:
				while True:
					chunk = response.read(1024 * 256)
					if not len(chunk):
						break
					current_size += len(chunk)
					fp.write(chunk)
					if total_size is not None:
						print("Progress [ {0: >5.2f}MB / {1: >5.2f}MB ]".format(toMB(current_size), total_size), end="\r")

		print("Progress: [ {0: >5.2f}MB / {0: >5.2f}MB ]\n".format(toMB(current_size)))
		print("Netronian Chaos v{0} successfully downloaded!".format(latest_version))

def toMB(bytes):
	return bytes / 1024 / 1024;

class ZDoomForumPostParser(html.parser.HTMLParser):

	depth_current = 0
	depth_post = 0
	processed_post = False

	def __init__(self):
		super().__init__()
		self.download_links = []

	def handle_starttag(self, tag, attrs):

		if tag in ("input", "option", "select") or self.processed_post:
			return

		# This conditional is used to identify where the first post starts,
		# and once it's found, to start processing link tags
		if (not self.depth_post and tag == "div"):
			attrs = dict(attrs)
			if "class" in attrs and "post" in attrs["class"].split(" "):
				self.depth_post = self.depth_current

		# This conditional allows us to process link tags once we're in
		# the expected first post on ZDoom forums; we'll be finding links
		# based on that
		if tag == "a":
			attrs = dict(attrs)
			url = attrs.get("href", None)
			if url:
				parsed_url = urllib.parse.urlparse(url)
				if "mediafire.com" in parsed_url.netloc:
					self.download_links.append(url)

		self.depth_current += 1

	def handle_endtag(self, tag):

		if tag in ("input", "option", "select") or self.processed_post:
			return

		self.depth_current -= 1

		if self.depth_post == self.depth_current and tag == "div":
			self.processed_post = True

	def handle_data(self, data):
		pass

	def handle_startendtag(self, tag, attrs):
		pass

	def feed(self, content):
		super().feed(content)
		return self.download_links

class MediafireDownloadParser(html.parser.HTMLParser):

	download_link = None

	def handle_starttag(self, tag, attrs):

		if not self.download_link:
			url = dict(attrs).get("href", None)
			if url:
				parsed_url = urllib.parse.urlparse(url)
				if parsed_url.netloc.startswith("download") and parsed_url.netloc.endswith("mediafire.com"):
					self.download_link = url

	def feed(self, content):
		super().feed(content)
		return self.download_link

if __name__ == "__main__":
	main(sys.argv[1])