# List of new codes
new_codes = [
    "TE449YKXEJEL",
    "4WH9NXLHAE7M",
    "PTYK4JHPA6PN",
    "MNL9K9L7N36H",
    "JT4NMTMYM4WM",
    "LAEP4K7THYFY",
    "HPFTH9PN9XXH",
    "JK7WWE3JYJ9E"
]

# Base text to replace the code in
base_text = "来啦😉，在Appstore里点自己头像，然后点兑换充值卡或代码：{} 期待使用感想，觉得好的话帮忙转发一下呀"

# Generating the list of texts with each code replaced
replaced_texts = [base_text.format(code) for code in new_codes]
replaced_texts
