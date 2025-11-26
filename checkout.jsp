<%-- 
    Document   : checkout
    Created on : Nov 26, 2025, 7:21:59 AM
    Author     : USER
--%>

<% @ page import="java.sql.*" %>
<% @ page import="java.util.Base64" %>
<% @ page session="true" %>
<% @ page contentType="text/html;charset=UTF-8" %>

<%
    String studentID = (String) session.getAttribute("studentID");
    if (studentID == null) {
        response.sendRedirect("login.html");
        return;
    }

    Connection conn = null;
    PreparedStatement ps = null, ps2 = null;
    ResultSet rs = null, rs2 = null;

    double grandTotal = 0;
%>

<!DOCTYPE html>
<html>
    <head>
        <title>Checkout</title>
        <link href="https://fonts.googleapis.com/css2?family=Poppins:wght @400;600;700&display=swap" rel="stylesheet">
        <style>
            body { font-family:'Poppins',sans-serif; background:#f2f4f8; padding:20px; }
            .container { max-width:900px; margin:auto; background:#fff; padding:30px; border-radius:12px; box-shadow:0 5px 20px rgba(0,0,0,0.1); }
            table { width:100%; border-collapse:collapse; margin-top:20px; }
            th,td { padding:12px; border-bottom:1px solid #ddd; text-align:center; }
            th { background:#4a6cf7; color:#fff; }
            img { border-radius:8px; }
            .qr-box { margin-top:20px; padding:20px; border:1px dashed #aaa; border-radius:12px; background:#fafafa; text-align:center; }
            .qr-box img { width:180px; border-radius:12px; border:3px solid #4a6cf7; }
            .btn { padding:12px 20px; background:#4CAF50; color:#fff; border:none; text-decoration:none; border-radius:10px; font-weight:600; }
            .btn:hover { background:#3e8e41; }
        </style>
    </head>
    <body>

        <div class="container">
            <h2>🛒 Checkout</h2>

            <%
                try {
                    Class.forName("org.apache.derby.jdbc.ClientDriver");
                    conn = DriverManager.getConnection("jdbc:derby://localhost:1527/MarketDB", "app", "app");

                    // ===================
                    // STEP 1: GET CART ITEMS + SELLER ID
                    // ===================
                    String sqlCart = "SELECT CI.cartItemID, CI.itemID, CI.quantity, I.title, I.price, I.image, "
                            + "I.studentID AS sellerID "
                            + "FROM CART C "
                            + "JOIN CART_ITEMS CI ON C.cartID = CI.cartID "
                            + "JOIN ITEMS I ON CI.itemID = I.itemID "
                            + "WHERE C.studentID=? AND CI.isActive=TRUE";

                    ps = conn.prepareStatement(sqlCart, ResultSet.TYPE_SCROLL_INSENSITIVE, ResultSet.CONCUR_READ_ONLY);
                    ps.setString(1, studentID);
                    rs = ps.executeQuery();

                    boolean hasItems = false;
                    String sellerID = "";

                    if (!rs.isBeforeFirst()) {
                        out.println("<p>Your cart is empty.</p>");
                        return;
                    }
            %>

            <form action="ProcessPaymentServlet" method="post" enctype="multipart/form-data">
                <table>
                    <tr>
                        <th>Item</th>
                        <th>Image</th>
                        <th>Price</th>
                        <th>Qty</th>
                        <th>Total</th>
                    </tr>

                    <%
                        while (rs.next()) {
                            hasItems = true;
                            sellerID = rs.getString("sellerID");
                            int itemID = rs.getInt("itemID");
                            int qty = rs.getInt("quantity");
                            double price = rs.getDouble("price");
                            double total = price * qty;
                            grandTotal += total;

                            byte[] imgBytes = rs.getBytes("image");
                            String imgSrc = imgBytes != null
                                    ? "data:image/jpeg;base64," + Base64.getEncoder().encodeToString(imgBytes)
                                    : "images/no-image.png";
                    %>
                    <tr>
                        <td><%= rs.getString("title")%></td>
                        <td><img src="<%= imgSrc%>" style="width:80px;height:80px;object-fit:cover;"></td>
                        <td>RM <%= String.format("%.2f", price)%></td>
                        <td><%= qty%></td>
                        <td>RM <%= String.format("%.2f", total)%></td>
                    </tr>

                    <!-- hidden inputs for this item -->
                    <input type="hidden" name="itemID" value="<%= itemID%>">
                    <input type="hidden" name="quantity" value="<%= qty%>">
                    <input type="hidden" name="price" value="<%= price%>">
                    <%
                } // end while
%>

                    <tr>
                        <th colspan="4">Grand Total</th>
                        <th>RM <%= String.format("%.2f", grandTotal)%></th>
                    </tr>
                </table>

                <%
                    // ===================
                    // STEP 2: GET SELLER PAYMENT DETAILS
                    // ===================
                    String sellerName = "";
                    String bankName = "";

                    String sqlSeller = "SELECT sellerName, bankName FROM SELLER_PAYMENT_INFO WHERE sellerID=?";
                    ps2 = conn.prepareStatement(sqlSeller, ResultSet.TYPE_SCROLL_INSENSITIVE, ResultSet.CONCUR_READ_ONLY);
                    ps2.setString(1, sellerID);
                    rs2 = ps2.executeQuery();

                    if (rs2.next()) {
                        sellerName = rs2.getString("sellerName");
                        bankName = rs2.getString("bankName");
                    }
                %>

                <h3>💳 Payment Information</h3>

                <div class="qr-box">
                    <p><strong>Seller:</strong> <%= sellerName%></p>
                    <p><strong>Bank / E-Wallet:</strong> <%= bankName%></p>
                    <p><strong>Scan to Pay:</strong></p>

                    <!-- QR loaded from servlet getQR -->
                    <img src="getQR?sellerID=<%= sellerID%>" alt="QR Code">
                </div>

                <input type="hidden" name="grandTotal" value="<%= grandTotal%>">

                <label><b>Upload Transfer Receipt:</b></label><br>
                <input type="file" name="paymentProof" accept="image/*,application/pdf" required><br><br>

                <button type="submit" class="btn">Submit Payment</button>
            </form>

            <br>
            <a href="buyerDashboard.jsp" class="btn" style="background:#888;">Cancel</a>

            <%
                } catch (Exception e) {
                    out.println("<p style='color:red;'>Error: " + e.getMessage() + "</p>");
                } finally {
                    try {
                        if (rs != null) {
                            rs.close();
                        }
                    } catch (Exception e) {
                    }
                    try {
                        if (rs2 != null) {
                            rs2.close();
                        }
                    } catch (Exception e) {
                    }
                    try {
                        if (ps != null) {
                            ps.close();
                        }
                    } catch (Exception e) {
                    }
                    try {
                        if (ps2 != null) {
                            ps2.close();
                        }
                    } catch (Exception e) {
                    }
                    try {
                        if (conn != null) {
                            conn.close();
                        }
                    } catch (Exception e) {
                    }
                }
            %>

        </div>
    </body>
</html>