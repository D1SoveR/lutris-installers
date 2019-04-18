#!/usr/bin/env python3

import html.parser
import re
import sys
import urllib.request
import urllib.parse

def download_package(package_name, forum_url, destination_file, version_regex):

	print("Attempting to identify latest version of {0}...".format(package_name))

	def link_filter(url):
		parsed_url = urllib.parse.urlparse(url)
		if not parsed_url.netloc.endswith("mediafire.com"):
			return False
		return True if version_regex.search(parsed_url.path) else False

	# Attempt to retrieve the HTML page of ZDoom forum post
	with urllib.request.urlopen(forum_url) as response:
		parser = ZDoomForumPostParser(link_filter)
		links_list = parser.feed(response.read().decode("utf-8"))

	if not len(links_list):
		raise Exception("No {0} links available".format(package_name))

	# Attempt to determine what the latest version of Netronian Chaos is;
	# do so by processing by version numbers in the links
	links_map = { k.group(0): v for (k, v) in zip(map(version_regex.search, links_list), links_list) if k }
	latest_version = sorted(links_map.keys())[-1]

	print("Found v{0} to be the latest, attempting to download it...".format(latest_version))

	# Attempt to retrieve the download link from Mediafire page
	with urllib.request.urlopen(links_map[latest_version]) as response:
		parser = MediafireDownloadParser()
		download_link = parser.feed(response.read().decode("utf-8"))

	# Attempt to download the file
	if download_link:
		download_file(download_link, destination_file, referer=links_map[latest_version], report=True)
		print("Successfully downloaded v{1} of {0}!".format(package_name, latest_version))
	else:
		raise Exception("Unable to download {0}".format(package_name))

def toMB(bytes):
	return bytes / 1024 / 1024;

class ZDoomForumPostParser(html.parser.HTMLParser):

	"""
	Parser class intended to process the first post in ZDoom forums thread for links,
	which can then be used to download the content itself. Upon parsing returns the list
	of all the links it has retrieved from that first post.
	"""

	depth_current = 0
	depth_post = 0
	processed_post = False

	def __init__(self, link_filter):
		super().__init__()
		self.download_links = []
		self.link_filter = link_filter

	def handle_starttag(self, tag, attrs):

		"""
		Handler for encountering opening tags.
		Its role is twofold; first, it attempts to find the tag of the first post
		on the forum thread, and once it encounters it, link scanning begins;
		second, it checks for links in that post and collects any that pass filtering.
		"""

		# We skip form controls (they can mess with depth estimation)
		if tag in ("input", "option", "select") or self.processed_post:
			return

		# This conditional is used to identify where the first post starts,
		# and once it's found, to start processing link tags
		if (not self.depth_post and tag == "div"):
			attrs = dict(attrs)
			if "class" in attrs and "post" in attrs["class"].split(" "):
				# Depth is used to ensure we correctly match the closing tag
				self.depth_post = self.depth_current

		# This conditional allows us to process link tags once we're in
		# the expected first post on ZDoom forums; we'll be finding links
		# based on result of the link filter.
		if tag == "a":
			attrs = dict(attrs)
			url = attrs.get("href", None)
			if url and self.link_filter(url):
				self.download_links.append(url)

		self.depth_current += 1

	def handle_endtag(self, tag):

		"""
		Handler for encountering closing tags.
		Its only role is to determine when we exit the first forum post;
		any processing after that can be fully ignored, as we don't collect
		any links from subsequent posts.
		"""

		if tag in ("input", "option", "select") or self.processed_post:
			return

		self.depth_current -= 1

		if self.depth_post == self.depth_current and tag == "div":
			self.processed_post = True

	def handle_startendtag(self, tag, attrs):
		"""
		Handler for self-closing tags.
		To simplify handling of <div> and <a> tags, we ignore them altogether.
		"""

	def feed(self, content):

		"""
		Parses the provided HTML content.
		Additionally, returns the list of all the links that have been
		found in the first post of the forum thread.
		"""

		super().feed(content)
		return self.download_links

class MediafireDownloadParser(html.parser.HTMLParser):

	"""
	Parser class intended to help with automatically downloading files from Mediafire.
	It goves over the document and finds the link pointing directly to the file we want
	to download; afterwards, any processing is ignored.
	"""

	download_link = None

	def handle_starttag(self, tag, attrs):

		"""
		Handler for opening tags.
		Its only role is to find the link pointing directly to the file.
		These can be identified for having "downloadXXXXX.mediafire.com" domain.
		"""

		if not self.download_link:
			url = dict(attrs).get("href", None)
			if url:
				parsed_url = urllib.parse.urlparse(url)
				if parsed_url.netloc.startswith("download") and parsed_url.netloc.endswith("mediafire.com"):
					self.download_link = url

	def feed(self, content):

		"""
		Parses the provided HTML content.
		Returns the link located within Mediafire page, or None if not found.
		"""

		super().feed(content)
		return self.download_link

def download_file(url, destination_file, referer=None, report=True):

	"""
	Helper function to download the contents of provided URL into given file.
	Optionally provides download progress based on provided Content-Length.
	"""

	request = urllib.request.Request(url, headers={ "Referer": referer }) if referer else url
	with urllib.request.urlopen(request) as response:

		current_size = 0
		total_size = dict(response.getheaders()).get("Content-Length", None) if report else None

		if report and total_size is not None:
			total_size = toMB(int(total_size))
		elif report:
			print("Progress: [ UNKNOWN ]", end="\r")

		with open(destination_file, mode="wb") as fp:
			while True:

				chunk = response.read(1024 * 256)
				fp.write(chunk)
				if not len(chunk):
					break

				if report:
					current_size += len(chunk)
					if total_size is not None:
						print("Progress [ {0: >5.2f}MB / {1: >5.2f}MB ]".format(toMB(current_size), total_size), end="\r")

		if report:
			print("Progress: [ {0: >5.2f}MB / {0: >5.2f}MB ]".format(toMB(current_size)))

if __name__ == "__main__":

	NETRONIAN_CHAOS_VERSION_REGEX = re.compile(r"(?<=v\.)([\d\.]+)(?=\.zip)")
	BUNGLE_IN_THE_JUNGLE_VERSION_REGEX = re.compile(r"(?<=_)([\d\.]+)(?=\.zip)")

	try:
		print("")
		download_package("Netronian Chaos", "https://forum.zdoom.org/viewtopic.php?f=43&t=57964", sys.argv[1], NETRONIAN_CHAOS_VERSION_REGEX)
		print("")
		download_package("Bungle in the Jungle", "https://forum.zdoom.org/viewtopic.php?f=42&t=61712", sys.argv[2], BUNGLE_IN_THE_JUNGLE_VERSION_REGEX)
	except Exception as e:
		print("")
		print("An error has occured, preventing all the packages from being downloaded")
		print("Try downloading the files manually, then using Custom installer")
		exit(1)