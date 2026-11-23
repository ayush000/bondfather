import Foundation

/// Markup trimmed from real nasdaqbaltic.com pages, plus one synthetic row for edge cases.
enum Fixtures {
    static let calendarPage = #"""
        <html><body>
        <table class="table">
          <thead><tr><th>Date</th><th>Issuer</th><th>Event</th><th>Market</th><th></th></tr></thead>
          <tbody>
            <tr>
              <td class="text-right">
                06.11.2026<br>
                <span class="text-muted">27.11.2026</span>
              </td>
              <td>Nordic Fibreboard <br><strong>SKN1T</strong></td>
              <td>
                <a href="https://view.news.eu.nasdaq.com/view?id=bfed96fcd25ad82d35acfe24f627ab190&amp;lang=en&amp;src=listed" target="_blank" class="text16 news-track"><strong>Public offering</strong></a>
              </td>
              <td>
                <span class="tickercode text12">TLN</span>
              </td>
              <td class="text-right"><a href="/statistics/en/calendar/download/22874" class="table-add">+</a></td>
            </tr>
            <tr>
              <td class="text-right">
                09.11.2026<br>
                <span class="text-muted">30.11.2026</span>
              </td>
              <td>PN Project <br><strong>PNPBOND_13</strong></td>
              <td>
                <a href="https://view.news.eu.nasdaq.com/view?id=1475833&amp;lang=en" target="_blank" class="text16 news-track"><strong>Public offering</strong></a>
              </td>
              <td>
                <span class="tickercode text12">TLN</span>
                <span class="tickercode text12">RIG</span>
                <span class="tickercode text12">VLN</span>
              </td>
              <td class="text-right"><a href="/statistics/en/calendar/download/22891" class="table-add">+</a></td>
            </tr>
            <tr>
              <td class="text-right">
                18.11.2026<br>
                <span class="text-muted">04.12.2026</span>
              </td>
              <td> <br><strong>LKOPBOND950</strong>
                <strong>LKOPBOND1000</strong>
              </td>
              <td>
                <a href="https://view.news.eu.nasdaq.com/view?id=1477619&amp;lang=en" target="_blank" class="text16 news-track"><strong>Public offering</strong></a>
              </td>
              <td>
                <span class="tickercode text12">TLN</span>
                <span class="tickercode text12">RIG</span>
              </td>
              <td class="text-right"><a href="/statistics/en/calendar/download/23048" class="table-add">+</a></td>
            </tr>
            <tr>
              <td class="text-right">01.12.2026</td>
              <td>Smith &amp; Sons</td>
              <td><a href="/statistics/en/news/123">Public offering</a></td>
              <td><span class="tickercode text12">RIG</span></td>
              <td></td>
            </tr>
          </tbody>
        </table>
        </body></html>
        """#

    static let announcementPage = #"""
        <div id="view-body"><p>
        <span style="font-size:12pt;">5 528 bonds of AS PN Project are being publicly offered to investors in Lithuania, Latvia and Estonia.</span></p>
        <table cellpadding="3" cellspacing="0" class="gnw_table">
        <tbody>
        <tr>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">Orderbook name</span></td>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">PNPBOND_13</span></td>
        </tr>
        <tr>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">ISIN code</span></td>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">LV0000104271</span></td>
        </tr>
        <tr>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">Dirty price of one security</span></td>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">EUR </span><span style="font-size:12pt;">1004.2662 </span><span style="font-size:12pt;">(100.42662%)</span></td>
        </tr>
        <tr>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">Minimum investment amount</span></td>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">EUR </span><span style="font-size:12pt;">1004.2662 </span><span style="font-size:12pt;">(1 bond)</span></td>
        </tr>
        <tr>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">Interest rate</span></td>
        <td class="gnw_uline" nowrap="nowrap" width="301"><span style="font-size:12pt;">10.00%</span></td>
        </tr>
        <tr>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">Offering period</span></td>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">09.11.2026 – 30.11.2026*</span></td>
        </tr>
        <tr>
        <td class="gnw_uline" width="301"><span style="font-size:12pt;">Settlement date</span></td>
        <td class="gnw_uline" nowrap="nowrap" width="301"><span style="font-size:12pt;">02.12.2026</span></td>
        </tr>
        </tbody>
        </table>
        <p><em><span style="font-size:12pt;">*Subscription order collection deadline might differ depending on the investor’s chosen bank or brokerage company.</span></em></p>
        </div>
        """#
}
