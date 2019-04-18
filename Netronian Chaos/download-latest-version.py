#!/usr/bin/env python3

import html.parser
import re
import ssl
import urllib.request
import urllib.parse

FORUM_URL = "https://forum.zdoom.org/viewtopic.php?f=43&t=57964"

def main():

	# Attempt to retrieve the HTML page of ZDoom forum post
	with request_url(FORUM_URL) as response:
		parser = ZDoomForumPostParser()
		links_list = parser.feed(response.read().decode("utf-8"))

	# Attempt to determine what the latest version of Netronian Chaos is;
	# do so by processing by version numbers in the links
	version_regex = re.compile(r"(?<=v\.)([\d\.]+)(?=\.zip)")
	netronian_links_map = { float(k.group(0)): v for (k, v) in zip(map(version_regex.search, links_list), links_list) if k }
	netronian_chaos_newest_url = netronian_links_map[max(*netronian_links_map.keys())]

	# Attempt to retrieve the download link from Mediafire page
	with request_url(netronian_chaos_newest_url) as response:
		print(response.getheaders())
		parser = MediafireDownloadParser()
		download_link = parser.feed(response.read().decode("utf-8"))

	if download_link:
		request = urllib.request.Request(download_link, headers={ "Referer": netronian_chaos_newest_url });
		try:
			response = request_url(request)
			print(response.getheaders())
		except Exception as e:
			print(e.fp.read())

def request_url(url):

	# This disables SSL verification
	no_verify_context = ssl.SSLContext()
	no_verify_context.verify_mode = ssl.CERT_NONE
	no_verify_context.verify_flags = ssl.VERIFY_DEFAULT

	return urllib.request.urlopen(url, context=no_verify_context)

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
	main()