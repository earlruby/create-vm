#!/usr/bin/python

# encrypt-pw - Returns a SHA512 encrypted password suitable for pasting into Kickstart files.

#   Copyright 2018 Earl C. Ruby III
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

import crypt
import getpass
import random
import string

salt = "$6$"
saltLen = 16
charSet = string.letters + string.digits + './'
for i in range(saltLen):
    salt = salt + random.choice(charSet)

print crypt.crypt(getpass.getpass(), salt)
