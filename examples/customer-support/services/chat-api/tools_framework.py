"""Function calling / tool use framework."""
import json
import logging
from typing import Dict, Any, Optional, List, Callable, Awaitable
from datetime import datetime, timedelta
from abc import ABC, abstractmethod

from models import Tool, ToolParameter


logger = logging.getLogger(__name__)


class ToolExecutionError(Exception):
    """Error during tool execution."""
    pass


class BaseTool(ABC):
    """Base class for tool implementations."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Tool name."""
        pass

    @property
    @abstractmethod
    def description(self) -> str:
        """Tool description."""
        pass

    @property
    @abstractmethod
    def parameters(self) -> Dict[str, ToolParameter]:
        """Tool parameters."""
        pass

    @abstractmethod
    async def execute(self, **kwargs) -> Dict[str, Any]:
        """Execute the tool.

        Args:
            **kwargs: Tool parameters

        Returns:
            Execution result
        """
        pass

    def to_tool_definition(self) -> Tool:
        """Convert to Tool model.

        Returns:
            Tool definition
        """
        return Tool(
            name=self.name,
            description=self.description,
            parameters=self.parameters,
        )


class GetOrderStatusTool(BaseTool):
    """Tool for retrieving order status."""

    # Mock database
    ORDERS_DB = {
        "ORD-12345": {
            "order_id": "ORD-12345",
            "status": "shipped",
            "tracking_number": "1Z999AA10123456784",
            "estimated_delivery": "2024-02-15",
            "items": [
                {"name": "Laptop", "quantity": 1, "price": 999.99}
            ],
        },
        "ORD-12346": {
            "order_id": "ORD-12346",
            "status": "processing",
            "tracking_number": None,
            "estimated_delivery": "2024-02-18",
            "items": [
                {"name": "Mouse", "quantity": 2, "price": 29.99}
            ],
        },
        "ORD-12347": {
            "order_id": "ORD-12347",
            "status": "delivered",
            "tracking_number": "1Z999AA10123456785",
            "estimated_delivery": "2024-02-10",
            "delivered_date": "2024-02-09",
            "items": [
                {"name": "Keyboard", "quantity": 1, "price": 79.99}
            ],
        },
    }

    @property
    def name(self) -> str:
        return "get_order_status"

    @property
    def description(self) -> str:
        return "Retrieve the current status of a customer order by order ID"

    @property
    def parameters(self) -> Dict[str, ToolParameter]:
        return {
            "order_id": ToolParameter(
                type="string",
                description="The unique order identifier (e.g., ORD-12345)",
                required=True,
            )
        }

    async def execute(self, order_id: str, **kwargs) -> Dict[str, Any]:
        """Execute order status lookup.

        Args:
            order_id: Order identifier

        Returns:
            Order status information
        """
        logger.info(f"Looking up order: {order_id}")

        if order_id not in self.ORDERS_DB:
            return {
                "success": False,
                "error": f"Order {order_id} not found",
                "message": "Please verify the order ID and try again.",
            }

        order = self.ORDERS_DB[order_id]
        return {
            "success": True,
            "order": order,
            "message": f"Order {order_id} is currently {order['status']}",
        }


class ScheduleAppointmentTool(BaseTool):
    """Tool for scheduling appointments."""

    # Mock appointments database
    APPOINTMENTS = []

    @property
    def name(self) -> str:
        return "schedule_appointment"

    @property
    def description(self) -> str:
        return "Schedule a customer service appointment"

    @property
    def parameters(self) -> Dict[str, ToolParameter]:
        return {
            "customer_name": ToolParameter(
                type="string",
                description="Customer's full name",
                required=True,
            ),
            "appointment_type": ToolParameter(
                type="string",
                description="Type of appointment",
                enum=["product_demo", "technical_support", "sales_consultation"],
                required=True,
            ),
            "preferred_date": ToolParameter(
                type="string",
                description="Preferred date in YYYY-MM-DD format",
                required=True,
            ),
            "preferred_time": ToolParameter(
                type="string",
                description="Preferred time in HH:MM format (24-hour)",
                required=True,
            ),
            "notes": ToolParameter(
                type="string",
                description="Additional notes or requirements",
                required=False,
            ),
        }

    async def execute(
        self,
        customer_name: str,
        appointment_type: str,
        preferred_date: str,
        preferred_time: str,
        notes: Optional[str] = None,
        **kwargs,
    ) -> Dict[str, Any]:
        """Execute appointment scheduling.

        Args:
            customer_name: Customer name
            appointment_type: Type of appointment
            preferred_date: Preferred date
            preferred_time: Preferred time
            notes: Optional notes

        Returns:
            Appointment confirmation
        """
        logger.info(
            f"Scheduling appointment for {customer_name} on {preferred_date} {preferred_time}"
        )

        # Validate appointment type
        valid_types = ["product_demo", "technical_support", "sales_consultation"]
        if appointment_type not in valid_types:
            return {
                "success": False,
                "error": f"Invalid appointment type: {appointment_type}",
                "valid_types": valid_types,
            }

        # Check if slot is available (simplified logic)
        slot_key = f"{preferred_date}_{preferred_time}"
        if any(a["slot_key"] == slot_key for a in self.APPOINTMENTS):
            return {
                "success": False,
                "error": "Time slot not available",
                "message": "Please select a different time.",
            }

        # Create appointment
        appointment_id = f"APT-{len(self.APPOINTMENTS) + 1:05d}"
        appointment = {
            "appointment_id": appointment_id,
            "customer_name": customer_name,
            "appointment_type": appointment_type,
            "date": preferred_date,
            "time": preferred_time,
            "notes": notes,
            "slot_key": slot_key,
            "status": "confirmed",
            "created_at": datetime.utcnow().isoformat(),
        }

        self.APPOINTMENTS.append(appointment)

        return {
            "success": True,
            "appointment": appointment,
            "message": (
                f"Appointment {appointment_id} scheduled for "
                f"{customer_name} on {preferred_date} at {preferred_time}"
            ),
        }


class SearchKnowledgeBaseTool(BaseTool):
    """Tool for searching knowledge base articles."""

    # Mock knowledge base
    KB_ARTICLES = [
        {
            "id": "KB-001",
            "title": "How to reset your password",
            "category": "account",
            "content": "To reset your password, click 'Forgot Password' on the login page...",
            "tags": ["password", "reset", "account", "login"],
        },
        {
            "id": "KB-002",
            "title": "Shipping and delivery information",
            "category": "shipping",
            "content": "We offer free shipping on orders over $50. Standard delivery takes 3-5 business days...",
            "tags": ["shipping", "delivery", "tracking"],
        },
        {
            "id": "KB-003",
            "title": "Return and refund policy",
            "category": "returns",
            "content": "You can return items within 30 days of purchase for a full refund...",
            "tags": ["return", "refund", "policy"],
        },
    ]

    @property
    def name(self) -> str:
        return "search_knowledge_base"

    @property
    def description(self) -> str:
        return "Search the knowledge base for relevant articles and information"

    @property
    def parameters(self) -> Dict[str, ToolParameter]:
        return {
            "query": ToolParameter(
                type="string",
                description="Search query or keywords",
                required=True,
            ),
            "category": ToolParameter(
                type="string",
                description="Optional category filter",
                enum=["account", "shipping", "returns", "billing", "technical"],
                required=False,
            ),
        }

    async def execute(
        self, query: str, category: Optional[str] = None, **kwargs
    ) -> Dict[str, Any]:
        """Execute knowledge base search.

        Args:
            query: Search query
            category: Optional category filter

        Returns:
            Search results
        """
        logger.info(f"Searching knowledge base: {query}")

        query_lower = query.lower()
        results = []

        for article in self.KB_ARTICLES:
            # Filter by category if specified
            if category and article["category"] != category:
                continue

            # Simple keyword matching
            score = 0
            for word in query_lower.split():
                if word in article["title"].lower():
                    score += 2
                if word in article["content"].lower():
                    score += 1
                if word in article["tags"]:
                    score += 1.5

            if score > 0:
                results.append({"article": article, "score": score})

        # Sort by relevance
        results.sort(key=lambda x: x["score"], reverse=True)

        return {
            "success": True,
            "query": query,
            "results": [r["article"] for r in results[:5]],  # Top 5 results
            "total_found": len(results),
        }


class ToolRegistry:
    """Registry for managing and executing tools."""

    def __init__(self):
        """Initialize tool registry."""
        self.tools: Dict[str, BaseTool] = {}
        self._register_default_tools()

    def _register_default_tools(self):
        """Register default tools."""
        default_tools = [
            GetOrderStatusTool(),
            ScheduleAppointmentTool(),
            SearchKnowledgeBaseTool(),
        ]

        for tool in default_tools:
            self.register(tool)

    def register(self, tool: BaseTool):
        """Register a tool.

        Args:
            tool: Tool to register
        """
        self.tools[tool.name] = tool
        logger.info(f"Registered tool: {tool.name}")

    def get_tool(self, name: str) -> Optional[BaseTool]:
        """Get a tool by name.

        Args:
            name: Tool name

        Returns:
            Tool instance or None
        """
        return self.tools.get(name)

    def get_all_tools(self) -> List[Tool]:
        """Get all tool definitions.

        Returns:
            List of Tool definitions
        """
        return [tool.to_tool_definition() for tool in self.tools.values()]

    async def execute_tool(
        self, tool_name: str, arguments: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Execute a tool with given arguments.

        Args:
            tool_name: Name of tool to execute
            arguments: Tool arguments

        Returns:
            Execution result

        Raises:
            ToolExecutionError: If tool not found or execution fails
        """
        tool = self.get_tool(tool_name)

        if not tool:
            raise ToolExecutionError(f"Tool not found: {tool_name}")

        try:
            logger.info(f"Executing tool: {tool_name} with args: {arguments}")
            result = await tool.execute(**arguments)
            logger.info(f"Tool {tool_name} executed successfully")
            return result

        except Exception as e:
            logger.error(f"Tool execution failed: {e}")
            raise ToolExecutionError(f"Failed to execute {tool_name}: {e}")

    async def execute_tool_calls(
        self, tool_calls: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Execute multiple tool calls.

        Args:
            tool_calls: List of tool call dictionaries with 'name' and 'arguments'

        Returns:
            List of execution results
        """
        results = []

        for call in tool_calls:
            tool_name = call.get("name")
            arguments = call.get("arguments", {})

            # Parse arguments if they're a JSON string
            if isinstance(arguments, str):
                try:
                    arguments = json.loads(arguments)
                except json.JSONDecodeError:
                    results.append(
                        {
                            "tool_name": tool_name,
                            "success": False,
                            "error": "Invalid JSON arguments",
                        }
                    )
                    continue

            try:
                result = await self.execute_tool(tool_name, arguments)
                results.append(
                    {
                        "tool_name": tool_name,
                        "success": True,
                        "result": result,
                    }
                )
            except ToolExecutionError as e:
                results.append(
                    {
                        "tool_name": tool_name,
                        "success": False,
                        "error": str(e),
                    }
                )

        return results
