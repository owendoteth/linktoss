from brownie import Coinflip, accounts

def main():
    dev = accounts.load('main')
    COINFLIP = Coinflip.deploy({"from": dev})

    # COINFLIP.create_game({"from": dev, "value": "1 ether"})
    # print(COINFLIP.get_game_info(0))
    # COINFLIP.join_game(0, {"from": dev, "value": "1 ether"})
    # print(COINFLIP.get_game_info(0))


