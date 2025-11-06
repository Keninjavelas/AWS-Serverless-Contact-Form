document.addEventListener("DOMContentLoaded", () => {
    
    // --- 1. SET YOUR API ENDPOINTS ---
    // !!! IMPORTANT: Replace this with your API's base URL
    const API_BASE_URL = "https://48uye0gol6.execute-api.us-east-1.amazonaws.com"; 
    
    const POST_MESSAGE_ENDPOINT = `${API_BASE_URL}/submit`;
    const GET_MESSAGES_ENDPOINT = `${API_BASE_URL}/messages`;
    
    // --- 2. GET REFERENCES TO HTML ELEMENTS ---
    const form = document.getElementById("contact-form");
    const statusMessage = document.getElementById("status-message");
    const submitButton = document.getElementById("submit-button");
    const guestbookFeed = document.getElementById("guestbook-feed");

    // --- 3. NEW FUNCTION: RENDER MESSAGES ---
    // This function builds the HTML for a single message card
    const createMessageCard = (message) => {
        const card = document.createElement("div");
        card.className = "message-card";
        
        const messageText = document.createElement("p");
        messageText.textContent = message.message;
        
        const metaDiv = document.createElement("div");
        metaDiv.className = "meta";
        
        const authorSpan = document.createElement("span");
        authorSpan.className = "author";
        authorSpan.textContent = message.name;
        
        const dateSpan = document.createElement("span");
        dateSpan.className = "date";
        // Format the date to be more readable
        dateSpan.textContent = new Date(message.createdAt).toLocaleString();

        metaDiv.appendChild(authorSpan);
        metaDiv.appendChild(dateSpan);
        card.appendChild(messageText);
        card.appendChild(metaDiv);
        
        return card;
    };

    // --- 4. NEW FUNCTION: LOAD MESSAGES ---
    // This function calls the GET /messages endpoint
    const loadMessages = async () => {
        guestbookFeed.innerHTML = "<p>Loading messages...</p>";
        try {
            const response = await fetch(GET_MESSAGES_ENDPOINT, {
                method: "GET",
            });
            
            if (!response.ok) {
                throw new Error("Failed to load messages.");
            }
            
            const messages = await response.json();
            
            // Clear the feed
            guestbookFeed.innerHTML = "";
            
            if (messages.length === 0) {
                guestbookFeed.innerHTML = "<p>No messages yet. Be the first!</p>";
            } else {
                // Loop through messages (they are pre-sorted)
                // and add a card for each one
                messages.forEach(message => {
                    const card = createMessageCard(message);
                    guestbookFeed.appendChild(card);
                });
            }
            
        } catch (error) {
            console.error("Error loading messages:", error);
            guestbookFeed.innerHTML = "<p>Error loading messages. Please try again.</p>";
            guestbookFeed.style.color = "red";
        }
    };

    // --- 5. UPDATED FORM SUBMIT HANDLER ---
    form.addEventListener("submit", async (e) => {
        e.preventDefault();

        submitButton.disabled = true;
        statusMessage.textContent = "Sending...";
        statusMessage.style.color = "#333";

        const formData = {
            name: document.getElementById("name").value,
            email: document.getElementById("email").value,
            message: document.getElementById("message").value
        };

        try {
            const response = await fetch(POST_MESSAGE_ENDPOINT, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(formData)
            });

            if (response.ok) {
                statusMessage.textContent = "Message sent successfully!";
                statusMessage.style.color = "green";
                form.reset();
                
                // --- NEW ---
                // Add the new message to the top of the feed instantly
                // We create a "fake" message object since we don't have
                // the full object from the DB, but this is faster.
                const newMessage = {
                    ...formData,
                    createdAt: new Date().toISOString() // Use current time
                };
                const newCard = createMessageCard(newMessage);
                
                // If the feed had "No messages", clear it first
                if (guestbookFeed.querySelector("p")) {
                    guestbookFeed.innerHTML = "";
                }
                
                // Add the new card to the very top
                guestbookFeed.prepend(newCard);
                // ----------------

            } else {
                const errorData = await response.json();
                statusMessage.textContent = `Error: ${errorData.message || 'Something went wrong.'}`;
                statusMessage.style.color = "red";
            }
        } catch (error) {
            console.error("Fetch error:", error);
            statusMessage.textContent = "Error: Could not connect to the server.";
            statusMessage.style.color = "red";
        } finally {
            submitButton.disabled = false;
        }
    });

    // --- 6. INITIAL PAGE LOAD ---
    // Load all messages as soon as the page opens
    loadMessages();
});