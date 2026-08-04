package com.wallmart.appliance.graphql;

import com.wallmart.appliance.inventory.InsufficientApplianceStockException;
import graphql.GraphQLError;
import graphql.GraphqlErrorBuilder;
import graphql.schema.DataFetchingEnvironment;
import org.springframework.graphql.data.method.annotation.GraphQlExceptionHandler;
import org.springframework.web.bind.annotation.ControllerAdvice;

@ControllerAdvice
public class GraphQlExceptionResolver {

  @GraphQlExceptionHandler(InsufficientApplianceStockException.class)
  public GraphQLError handleInsufficientStock(
      InsufficientApplianceStockException ex, DataFetchingEnvironment env) {
    return GraphqlErrorBuilder.newError(env)
        .message(ex.getMessage())
        .errorType(graphql.ErrorType.DataFetchingException)
        .build();
  }

  @GraphQlExceptionHandler(IllegalArgumentException.class)
  public GraphQLError handleIllegalArgument(
      IllegalArgumentException ex, DataFetchingEnvironment env) {
    return GraphqlErrorBuilder.newError(env)
        .message(ex.getMessage())
        .errorType(graphql.ErrorType.ValidationError)
        .build();
  }
}
