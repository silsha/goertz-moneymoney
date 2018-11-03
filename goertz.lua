--
-- MoneyMoney Web Banking extension
-- http://moneymoney-app.com/api/webbanking
--
--
-- The MIT License (MIT)
--
-- Copyright (c) Silsha Fux
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--
-- Get balance for Görtz Vorteilskarte
--

function MM.makeTimeStamp(dateString)
    local pattern = "(%d+)%.(%d+)%.(%d+)"
    local xday, xmonth, xyear = dateString:match(pattern)
    local convertedTimestamp = os.time({year = xyear, month = xmonth,
        day = xday})
    return convertedTimestamp
end

WebBanking {
    version     = 1.10,
    country     = "de",
    url         = "https://vorteilskarte.baeckergoertz.de",
    services    = {"Bäckerei Görtz"},
    description = string.format(MM.localizeText("Get balance for %s"), "Bäckerei Görtz")
}

function SupportsBank (protocol, bankCode)
    return bankCode == "Bäckerei Görtz" and protocol == ProtocolWebBanking
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
    connection = Connection()
    connection.language = "de-de"

    local response = HTML(connection:get(url))
    response:xpath("//*[@id='login__EA__ean__EZ__']"):attr("value", username)
    response:xpath("//*[@id='login__EA__pin_jetzt__EZ__']"):attr("value", password)
    response = HTML(connection:request(response:xpath("//*[@id='form_loginform']//button"):click()))


    print(response:xpath("//*[@class='fehlermeldung']"):text())
    if (response:xpath("//*[@class='fehlermeldung']"):text() == 'EAN und / oder PIN / Passwort haben leider nicht gestimmt oder Ihr Benutzerkonto wurde wegen zu vieler Fehlversuche beim Login gesperrt. Bitte versuchen Sie es noch einmal oder fordern Sie ein neues Passwort per E-Mail an.') then
        return LoginFailed
    end
end

function ListAccounts (knownAccounts)
    print("LIST ACCOUNTS")
    local accounts = {}
    local response = HTML(connection:get(url .. "/Karten_verwalten"))
    response:xpath("//*[@id='form_karten_verwalten']//tr"):each(function (index, row)
        print(index)
        if (index > 0) then
            local accNrStr = {}
            for w in string.gmatch(row:xpath("//*[@class='ean']"):text(), "%d+") do
                table.insert(accNrStr, w)
            end

            local account = {
                name = row:xpath("//*[@class='ean']"):text(),
                owner = "owner",
                accountNumber = accNrStr[index],
                currency = "EUR",
                type = AccountTypeOther,
                portfolio = false
            }

            table.insert(accounts, account)
        end

    end)

    print("ListAccounts successful.")
    return accounts
end

function RefreshAccount (account, since)
    local transactions = {}
    local response = HTML(connection:get(url .. "/Umsatzliste"))

    response:xpath("//*[@class='umsatzliste table']//tr"):each(function (index, row)
        if index > 1 then
            local transaction = {}
            transaction = {
                bookingDate = MM.makeTimeStamp(row:xpath("td[1]"):text()),
                name = row:xpath("td[2]"):text(),
                purpose = row:xpath("td[3]"):text(),
                currency = "EUR",
                amount = row:xpath("td[4]"):text():gsub(",", "."):gsub(" €", ""):gsub("+", ""),
            }
            table.insert(transactions, transaction)
        end

    end)

    local balance = response:xpath('//*[@id="umsatzliste__EA__karte__EZ__"]/option'):text():gsub(account.accountNumber, ""):gsub(",", "."):gsub(" €", ""):gsub(" ","")

    return {balance = balance, transactions = transactions}
end

function EndSession ()
    connection:get(url .. "/Logout")

    print("Logout successful.")
end