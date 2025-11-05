"""Tests for tools framework."""
import pytest

from tools_framework import (
    ToolRegistry,
    GetOrderStatusTool,
    ScheduleAppointmentTool,
    SearchKnowledgeBaseTool,
    ToolExecutionError,
)


@pytest.mark.asyncio
class TestTools:
    """Tests for tools framework."""

    def setup_method(self):
        """Set up test fixtures."""
        self.registry = ToolRegistry()

    async def test_get_order_status_success(self):
        """Test successful order status lookup."""
        tool = GetOrderStatusTool()
        result = await tool.execute(order_id="ORD-12345")

        assert result["success"]
        assert result["order"]["order_id"] == "ORD-12345"
        assert result["order"]["status"] == "shipped"

    async def test_get_order_status_not_found(self):
        """Test order not found."""
        tool = GetOrderStatusTool()
        result = await tool.execute(order_id="ORD-99999")

        assert not result["success"]
        assert "error" in result

    async def test_schedule_appointment_success(self):
        """Test successful appointment scheduling."""
        tool = ScheduleAppointmentTool()
        result = await tool.execute(
            customer_name="John Doe",
            appointment_type="product_demo",
            preferred_date="2024-03-01",
            preferred_time="14:00",
            notes="Interested in enterprise features",
        )

        assert result["success"]
        assert "appointment" in result
        assert result["appointment"]["customer_name"] == "John Doe"

    async def test_schedule_appointment_invalid_type(self):
        """Test appointment with invalid type."""
        tool = ScheduleAppointmentTool()
        result = await tool.execute(
            customer_name="John Doe",
            appointment_type="invalid_type",
            preferred_date="2024-03-01",
            preferred_time="14:00",
        )

        assert not result["success"]
        assert "error" in result

    async def test_schedule_appointment_conflict(self):
        """Test appointment time conflict."""
        tool = ScheduleAppointmentTool()

        # Schedule first appointment
        await tool.execute(
            customer_name="John Doe",
            appointment_type="product_demo",
            preferred_date="2024-03-01",
            preferred_time="14:00",
        )

        # Try to schedule at same time
        result = await tool.execute(
            customer_name="Jane Smith",
            appointment_type="sales_consultation",
            preferred_date="2024-03-01",
            preferred_time="14:00",
        )

        assert not result["success"]
        assert "not available" in result["error"].lower()

    async def test_search_knowledge_base_success(self):
        """Test successful knowledge base search."""
        tool = SearchKnowledgeBaseTool()
        result = await tool.execute(query="password reset")

        assert result["success"]
        assert len(result["results"]) > 0
        assert any("password" in r["title"].lower() for r in result["results"])

    async def test_search_knowledge_base_with_category(self):
        """Test knowledge base search with category filter."""
        tool = SearchKnowledgeBaseTool()
        result = await tool.execute(query="shipping", category="shipping")

        assert result["success"]
        assert all(r["category"] == "shipping" for r in result["results"])

    async def test_search_knowledge_base_no_results(self):
        """Test knowledge base search with no results."""
        tool = SearchKnowledgeBaseTool()
        result = await tool.execute(query="xyzabc123nonexistent")

        assert result["success"]
        assert len(result["results"]) == 0

    async def test_tool_registry_get_all_tools(self):
        """Test getting all tool definitions."""
        tools = self.registry.get_all_tools()

        assert len(tools) >= 3
        tool_names = {tool.name for tool in tools}
        assert "get_order_status" in tool_names
        assert "schedule_appointment" in tool_names
        assert "search_knowledge_base" in tool_names

    async def test_tool_registry_execute_tool(self):
        """Test executing tool via registry."""
        result = await self.registry.execute_tool(
            "get_order_status", {"order_id": "ORD-12345"}
        )

        assert result["success"]
        assert result["order"]["order_id"] == "ORD-12345"

    async def test_tool_registry_execute_nonexistent_tool(self):
        """Test executing nonexistent tool."""
        with pytest.raises(ToolExecutionError):
            await self.registry.execute_tool("nonexistent_tool", {})

    async def test_tool_registry_execute_tool_calls(self):
        """Test executing multiple tool calls."""
        tool_calls = [
            {
                "name": "get_order_status",
                "arguments": {"order_id": "ORD-12345"},
            },
            {
                "name": "search_knowledge_base",
                "arguments": {"query": "shipping"},
            },
        ]

        results = await self.registry.execute_tool_calls(tool_calls)

        assert len(results) == 2
        assert all(r["success"] for r in results)

    async def test_tool_registry_execute_with_json_string(self):
        """Test executing tool with JSON string arguments."""
        import json

        tool_calls = [
            {
                "name": "get_order_status",
                "arguments": json.dumps({"order_id": "ORD-12345"}),
            }
        ]

        results = await self.registry.execute_tool_calls(tool_calls)

        assert len(results) == 1
        assert results[0]["success"]

    async def test_tool_to_definition(self):
        """Test converting tool to definition."""
        tool = GetOrderStatusTool()
        definition = tool.to_tool_definition()

        assert definition.name == "get_order_status"
        assert definition.description
        assert "order_id" in definition.parameters

    def test_tool_parameters(self):
        """Test tool parameter definitions."""
        tool = ScheduleAppointmentTool()

        assert "customer_name" in tool.parameters
        assert "appointment_type" in tool.parameters
        assert tool.parameters["customer_name"].required
        assert tool.parameters["appointment_type"].enum is not None
